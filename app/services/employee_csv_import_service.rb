# frozen_string_literal: true

class EmployeeCsvImportService
  ImportResult = Struct.new(:imported, :skipped, :errors)

  # Mapping flexible des noms de colonnes — insensible à la casse et aux accents
  COLUMN_ALIASES = {
    'first_name'    => %w[prenom firstname first_name],
    'last_name'     => %w[nom lastname last_name],
    'email'         => %w[email mail e-mail],
    'phone'         => %w[telephone phone mobile],
    'department'    => %w[departement department dept service],
    'job_title'     => %w[poste titre fonction job_title],
    'contract_type' => %w[contrat type_contrat contract contract_type type_de_contrat],
    'start_date'    => %w[date_entree date_arrivee date_debut start_date date_d_entree date_d_arrivee],
    'end_date'      => %w[date_fin end_date date_de_fin],
    'gross_salary'  => %w[salaire salaire_brut gross_salary remuneration],
    'manager_email' => %w[manager manager_email responsable],
    'role'          => %w[role profil]
  }.freeze

  CONTRACT_ALIASES = {
    'cdi'         => 'CDI',
    'cdd'         => 'CDD',
    'stage'       => 'Stage',
    'alternance'  => 'Alternance',
    'interim'     => 'Interim',
    'intérim'     => 'Interim',
    'interimaire' => 'Interim'
  }.freeze

  MAX_FILE_SIZE = 5.megabytes

  def initialize(file, organization)
    @file         = file
    @organization = organization
  end

  def call
    return size_error if @file.size > MAX_FILE_SIZE

    rows   = parse_file
    result = ImportResult.new([], [], [])

    # 1st pass — create all employees (no manager yet)
    ActsAsTenant.with_tenant(@organization) do
      ActiveRecord::Base.transaction do
        rows.each_with_index do |row, i|
          import_row(row, i + 2, result)
        end
      end
    end

    # 2nd pass — resolve managers (all employees now exist)
    resolve_managers(rows, result)

    result
  rescue CSV::MalformedCSVError => e
    ImportResult.new([], [], ["Fichier CSV invalide : #{e.message}"])
  rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
    ImportResult.new([], [], ["Encodage invalide — sauvegardez le fichier en UTF-8 et réessayez."])
  rescue Roo::HeaderRowNotFoundError => e
    ImportResult.new([], [], ["En-têtes manquants dans le fichier Excel : #{e.message}"])
  end

  private

  def size_error
    ImportResult.new([], [], ["Fichier trop volumineux (max 5 Mo)."])
  end

  def parse_file
    ext = File.extname(@file.original_filename.to_s).downcase
    if ext.in?(%w[.xlsx .xls])
      parse_xlsx
    else
      parse_csv
    end
  end

  # ── XLSX parser ─────────────────────────────────────────────────────────────

  def parse_xlsx
    spreadsheet = Roo::Spreadsheet.open(@file.path, extension: :xlsx)
    sheet = spreadsheet.sheet(0)

    # Find the header row — some exports add a title row before the real headers.
    # We scan the first 5 rows and use the first one that contains a recognized column.
    header_row_index = (1..[ 5, sheet.last_row ].min).find do |i|
      sheet.row(i).any? { |h| normalize_header(h.to_s) != h.to_s.downcase.strip }
    end || 1

    headers = sheet.row(header_row_index).map { |h| normalize_header(h.to_s) }

    rows = []
    ((header_row_index + 1)..sheet.last_row).each do |i|
      values = sheet.row(i).map { |v| xlsx_cell_value(v) }
      rows << headers.zip(values).to_h
    end
    rows
  end

  def xlsx_cell_value(val)
    case val
    when Date, DateTime, Time
      val.strftime('%d/%m/%Y')
    when Float
      # Excel stores integers as floats (e.g. 58000.0) — clean it up
      val == val.floor ? val.to_i.to_s : val.to_s
    when nil
      nil
    else
      str = val.to_s.strip
      # Excel wraps hyperlinks as <html><u>value</u></html> — strip the tags
      str = str.gsub(/<[^>]+>/, '').strip if str.start_with?('<')
      str.presence
    end
  end

  # ── CSV parser ───────────────────────────────────────────────────────────────

  def parse_csv
    raw = @file.read
    content = decode_to_utf8(raw)
    content.gsub!("\xEF\xBB\xBF", '') # strip UTF-8 BOM
    sep = content.count(';') >= content.count(',') ? ';' : ','
    CSV.parse(content, headers: true, col_sep: sep,
              header_converters: ->(h) { normalize_header(h) })
       .map(&:to_h)
  end

  # Try common encodings used by Excel (Windows-1252, ISO-8859-1) before UTF-8 fallback.
  def decode_to_utf8(raw)
    return raw if raw.encoding == Encoding::UTF_8 && raw.valid_encoding?

    %w[UTF-8 Windows-1252 ISO-8859-1].each do |enc|
      begin
        converted = raw.dup.force_encoding(enc).encode('UTF-8')
        return converted if converted.valid_encoding?
      rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
        next
      end
    end

    # Last resort — replace invalid bytes
    raw.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
  end

  # ── Shared helpers ───────────────────────────────────────────────────────────

  def normalize_header(header)
    normalized = header.to_s.downcase.strip
                       .gsub(/[éèêë]/, 'e')
                       .gsub(/[àâä]/, 'a')
                       .gsub(/[îï]/, 'i')
                       .gsub(/[ôö]/, 'o')
                       .gsub(/[ùûü]/, 'u')
                       .gsub(/[ç]/, 'c')
                       .gsub(/[\s\-()'']+/, '_')
                       .gsub(/_+/, '_')
                       .gsub(/\A_|_\z/, '')
    COLUMN_ALIASES.each do |canonical, aliases|
      return canonical if aliases.include?(normalized)
    end
    normalized
  end

  def import_row(row, line_num, result)
    attrs = build_employee_attrs(row)

    if attrs[:first_name].blank? || attrs[:last_name].blank? || attrs[:email].blank?
      result.errors << "Ligne #{line_num} : Prénom, Nom et Email sont obligatoires"
      result.skipped << row
      return
    end

    employee = Employee.new(attrs.merge(
      organization: @organization,
      password:     SecureRandom.hex(10)
    ))

    if employee.save
      result.imported << employee
    else
      result.errors << "Ligne #{line_num} (#{row['email']}) : #{employee.errors.full_messages.join(', ')}"
      result.skipped << row
    end
  end

  def build_employee_attrs(row)
    {
      first_name:         row['first_name'].to_s.strip,
      last_name:          row['last_name'].to_s.strip,
      email:              row['email'].to_s.strip.downcase,
      phone:              row['phone']&.strip.presence,
      department:         row['department']&.strip.presence,
      job_title:          row['job_title']&.strip.presence,
      contract_type:      normalize_contract(row['contract_type']),
      start_date:         parse_date(row['start_date']),
      end_date:           parse_date(row['end_date']),
      gross_salary_cents: parse_salary(row['gross_salary']),
      role:               normalize_role(row['role'])
    }.compact
  end

  def normalize_contract(val)
    CONTRACT_ALIASES[val.to_s.downcase.strip] || 'CDI'
  end

  def normalize_role(val)
    r = val.to_s.downcase.strip
    Employee::ROLES.include?(r) ? r : 'employee'
  end

  def parse_date(val)
    return nil if val.blank?
    str = val.strip
    %w[%d/%m/%Y %Y-%m-%d %d-%m-%Y %m/%d/%Y].each do |fmt|
      begin
        return Date.strptime(str, fmt)
      rescue Date::Error, ArgumentError
        next
      end
    end
    nil
  end

  def parse_salary(val)
    return nil if val.blank?
    cleaned = val.to_s.gsub(/[^\d.,]/, '').gsub(/,(?=\d{2}\z)/, '.').gsub(',', '')
    cents = cleaned.to_f * 100
    cents.positive? ? cents.to_i : nil
  end

  def resolve_managers(rows, result)
    ActsAsTenant.with_tenant(@organization) do
      rows.each do |row|
        next if row['manager_email'].blank?

        manager_email  = row['manager_email'].strip.downcase
        employee_email = row['email']&.strip&.downcase
        next if employee_email.blank?

        employee = Employee.find_by(email: employee_email)
        manager  = Employee.find_by(email: manager_email)

        next unless employee && manager

        employee.update_columns(manager_id: manager.id)
      end
    end
  end
end
