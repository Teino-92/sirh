# frozen_string_literal: true

module HrQuery
  # Translates the structured filter JSON from HrQueryInterpreterService
  # into ActiveRecord scopes. Never generates raw SQL.
  #
  # SECURITY:
  # - acts_as_tenant ensures organization_id scoping on all models
  # - Salary visibility is re-checked here (cannot be bypassed by LLM)
  # - MAX_RESULTS caps the result set to prevent browser overload
  class HrQueryExecutorService
    MAX_RESULTS = 500

    attr_reader :filters, :requester

    # @param filters  [Hash]     Parsed filter JSON from the interpreter
    # @param requester [Employee] The authenticated employee making the request
    def initialize(filters, requester)
      @filters   = filters.with_indifferent_access
      @requester = requester
    end

    # Returns an Array of plain hashes, one per employee, with only the
    # requested output columns populated.
    def call
      employees = base_scope
      employees = apply_employee_filters(employees)
      employees = apply_leave_filter(employees)
      employees = apply_evaluation_filter(employees)
      employees = apply_onboarding_filter(employees)
      employees = apply_one_on_one_filter(employees)
      employees = apply_objective_filter(employees)
      employees = apply_time_tracking_filter(employees)
      employees = apply_training_filter(employees)

      employees = employees.limit(MAX_RESULTS).order(:last_name, :first_name)
      build_rows(employees)
    end

    private

    # ─── Base scope ────────────────────────────────────────────────────────────

    def base_scope
      scope = Employee.all
      scope = scope.active if employee_filters[:active_only] != false
      scope
    end

    # ─── Employee filters ───────────────────────────────────────────────────────

    def apply_employee_filters(scope)
      ef = employee_filters

      scope = scope.where(department: ef[:department])             if ef[:department].present?
      scope = scope.where(role: ef[:role])                         if ef[:role].present?
      scope = scope.where(contract_type: ef[:contract_type])       if ef[:contract_type].present?
      scope = scope.where("job_title ILIKE ?", "%#{ef[:job_title_contains]}%") if ef[:job_title_contains].present?

      if ef[:cadre].in?([true, false])
        if ef[:cadre]
          scope = scope.where("(settings->>'cadre') = 'true'")
        else
          scope = scope.where("(settings->>'cadre') IS NULL OR (settings->>'cadre') = 'false'")
        end
      end

      if ef[:start_date_from].present?
        scope = scope.where("start_date >= ?", Date.parse(ef[:start_date_from].to_s))
      end
      if ef[:start_date_to].present?
        scope = scope.where("start_date <= ?", Date.parse(ef[:start_date_to].to_s))
      end

      # Tenure filters: convert months to approximate dates
      if ef[:tenure_months_min].present?
        cutoff = Date.current - (ef[:tenure_months_min].to_i * 30).days
        scope = scope.where("start_date <= ?", cutoff)
      end
      if ef[:tenure_months_max].present?
        cutoff = Date.current - (ef[:tenure_months_max].to_i * 30).days
        scope = scope.where("start_date >= ?", cutoff)
      end

      scope
    rescue ArgumentError
      # Invalid date string from LLM — ignore filter gracefully
      scope
    end

    # ─── Leave filter ───────────────────────────────────────────────────────────

    def apply_leave_filter(scope)
      lf = leave_filters
      return scope unless any_present?(lf, :leave_type, :days_used_min, :days_used_max, :period_year, :status)

      # Build subquery: employee IDs matching leave criteria
      # Exclude rejected requests unless a specific status filter is requested
      leave_scope = LeaveRequest.all
      leave_scope = leave_scope.where(leave_type: lf[:leave_type]) if lf[:leave_type].present?
      if lf[:status].present?
        leave_scope = leave_scope.where(status: lf[:status])
      else
        leave_scope = leave_scope.where.not(status: 'rejected')
      end

      if lf[:period_year].present?
        year = lf[:period_year].to_i
        leave_scope = leave_scope.where(
          "EXTRACT(YEAR FROM start_date) = ? OR EXTRACT(YEAR FROM end_date) = ?",
          year, year
        )
      end

      # Aggregate days_count per employee, then filter
      if lf[:days_used_min].present? || lf[:days_used_max].present?
        aggregated = leave_scope
          .group(:employee_id)
          .select("employee_id, SUM(days_count) AS total_days")

        if lf[:days_used_min].present?
          aggregated = aggregated.having("SUM(days_count) >= ?", lf[:days_used_min].to_f)
        end
        if lf[:days_used_max].present?
          aggregated = aggregated.having("SUM(days_count) <= ?", lf[:days_used_max].to_f)
        end

        employee_ids = aggregated.map(&:employee_id)
        scope = scope.where(id: employee_ids)
      else
        scope = scope.where(id: leave_scope.select(:employee_id))
      end

      scope
    end

    # ─── Evaluation filter ──────────────────────────────────────────────────────

    def apply_evaluation_filter(scope)
      ef = evaluation_filters
      return scope unless any_present?(ef, :score_min, :score_max, :period_year, :status)

      eval_scope = Evaluation.all
      eval_scope = eval_scope.where(status: ef[:status])     if ef[:status].present?
      eval_scope = eval_scope.by_period(ef[:period_year])    if ef[:period_year].present?

      # Score enum: insufficient=1, below_expectations=2, meets_expectations=3,
      #             exceeds_expectations=4, exceptional=5
      if ef[:score_min].present?
        eval_scope = eval_scope.where("score >= ?", ef[:score_min].to_i)
      end
      if ef[:score_max].present?
        eval_scope = eval_scope.where("score <= ?", ef[:score_max].to_i)
      end

      scope.where(id: eval_scope.select(:employee_id))
    end

    # ─── Onboarding filter ──────────────────────────────────────────────────────

    def apply_onboarding_filter(scope)
      of = onboarding_filters
      return scope unless any_present?(of, :status, :integration_score_min, :integration_score_max)

      onboarding_scope = EmployeeOnboarding.all
      onboarding_scope = onboarding_scope.where(status: of[:status]) if of[:status].present?

      if of[:integration_score_min].present?
        onboarding_scope = onboarding_scope.where(
          "integration_score_cache >= ?", of[:integration_score_min].to_i
        )
      end
      if of[:integration_score_max].present?
        onboarding_scope = onboarding_scope.where(
          "integration_score_cache <= ?", of[:integration_score_max].to_i
        )
      end

      scope.where(id: onboarding_scope.select(:employee_id))
    end

    # ─── One-on-one filter ──────────────────────────────────────────────────────

    def apply_one_on_one_filter(scope)
      of = one_on_one_filters
      return scope unless any_present?(of, :no_meeting_since_days, :total_completed_min)

      if of[:no_meeting_since_days].present?
        cutoff = Date.current - of[:no_meeting_since_days].to_i.days
        # Employés dont le dernier 1:1 complété est avant la cutoff OU qui n'en ont aucun
        had_recent = OneOnOne.where(status: :completed)
                             .where('completed_at >= ?', cutoff)
                             .select(:employee_id)
        scope = scope.where.not(id: had_recent)
      end

      if of[:total_completed_min].present?
        period = of[:period_days].present? ? of[:period_days].to_i.days.ago : 1.year.ago
        enough = OneOnOne.where(status: :completed)
                         .where('completed_at >= ?', period)
                         .group(:employee_id)
                         .having('COUNT(*) >= ?', of[:total_completed_min].to_i)
                         .select(:employee_id)
        scope = scope.where(id: enough)
      end

      scope
    end

    # ─── Objective filter ───────────────────────────────────────────────────────

    def apply_objective_filter(scope)
      of = objective_filters
      return scope unless any_present?(of, :status, :overdue, :priority)

      obj_scope = Objective.where(owner_type: 'Employee')
      obj_scope = obj_scope.where(status: of[:status])    if of[:status].present?
      obj_scope = obj_scope.where(priority: of[:priority]) if of[:priority].present?
      if of[:overdue].in?([true, 'true'])
        obj_scope = obj_scope.overdue
      end

      scope.where(id: obj_scope.select(:owner_id))
    end

    # ─── Time tracking filter ───────────────────────────────────────────────────

    def apply_time_tracking_filter(scope)
      tf = time_tracking_filters
      return scope unless any_present?(tf, :late_checkins_min)

      period = tf[:period_days].present? ? tf[:period_days].to_i.days.ago : 30.days.ago

      # late? logic: clock_in > expected start + 5 min
      # We use a subquery counting entries where clock_in is late
      # Since late? is a Ruby method, we load IDs via a batch approach
      employee_ids = scope.pluck(:id)
      late_counts = Hash.new(0)

      TimeEntry.where(employee_id: employee_ids)
               .where('clock_in >= ?', period)
               .find_each do |entry|
        late_counts[entry.employee_id] += 1 if entry.late?
      end

      qualifying_ids = late_counts.select { |_, count| count >= tf[:late_checkins_min].to_i }.keys
      scope.where(id: qualifying_ids)
    end

    # ─── Training filter ────────────────────────────────────────────────────────

    def apply_training_filter(scope)
      tf = training_filters
      return scope unless any_present?(tf, :status)

      # TrainingAssignment has no acts_as_tenant — scope via JOIN on trainings
      assignment_scope = TrainingAssignment
        .joins(:training)
        .where(trainings: { organization_id: ActsAsTenant.current_tenant.id })
        .where(status: tf[:status])
      scope.where(id: assignment_scope.select(:employee_id))
    end

    # ─── Row building ───────────────────────────────────────────────────────────

    def build_rows(employees)
      cols    = output_columns
      can_see_salary = requester.hr_or_admin?

      # Eager-load associations needed for certain columns
      if (cols & %w[leave_days_used leave_type]).any?
        employees = employees.includes(:leave_balances)
      end
      if (cols & %w[evaluation_score evaluation_status]).any?
        employees = employees.includes(:evaluations)
      end
      if (cols & %w[onboarding_status integration_score]).any?
        employees = employees.includes(:employee_onboardings)
      end
      if (cols & %w[last_one_on_one_date one_on_one_count]).any?
        employees = employees.includes(:one_on_ones)
      end
      if (cols & %w[objective_status objective_count]).any?
        employees = employees.includes(:objectives)
      end
      if cols.include?('training_status')
        employees = employees.includes(:training_assignments)
      end

      employees.map do |emp|
        row = {}
        cols.each do |col|
          row[col] = cell_value(emp, col, can_see_salary)
        end
        row
      end
    end

    def cell_value(emp, col, can_see_salary)
      case col
      when "name"             then emp.full_name
      when "department"       then emp.department
      when "role"             then emp.role
      when "contract_type"    then emp.contract_type
      when "job_title"        then emp.job_title
      when "start_date"       then emp.start_date&.strftime('%d/%m/%Y')
      when "tenure_months"    then emp.tenure_in_months
      when "leave_days_used"  then leave_days_used(emp)
      when "leave_type"       then leave_type_for(emp)
      when "evaluation_score" then latest_evaluation_score(emp)
      when "evaluation_status" then latest_evaluation_status(emp)
      when "onboarding_status"  then emp.employee_onboardings.active.first&.status
      when "integration_score"  then emp.employee_onboardings.active.first&.integration_score_cache
      when "salary"           then can_see_salary ? format_salary(emp) : "—"
      when "last_one_on_one_date"
        last = emp.one_on_ones.where(status: :completed).order(completed_at: :desc).first
        last ? "#{(Date.current - last.completed_at.to_date).to_i}j" : "Jamais"
      when "one_on_one_count"
        period = one_on_one_filters[:period_days].present? ? one_on_one_filters[:period_days].to_i.days.ago : 1.year.ago
        emp.one_on_ones.where(status: :completed).where('completed_at >= ?', period).count
      when "objective_status"
        obj = emp.objectives.active.order(deadline: :asc).first
        obj&.status || "—"
      when "objective_count"
        of = objective_filters
        obj_scope = emp.objectives
        obj_scope = obj_scope.where(status: of[:status]) if of[:status].present?
        obj_scope.count
      when "late_checkins_count"
        period = time_tracking_filters[:period_days].present? ? time_tracking_filters[:period_days].to_i.days.ago : 30.days.ago
        emp.time_entries.where('clock_in >= ?', period).select(&:late?).count
      when "training_status"
        emp.training_assignments.order(assigned_at: :desc).first&.status || "—"
      else nil
      end
    end

    def leave_days_used(emp)
      lf    = leave_filters
      year  = lf[:period_year]&.to_i
      ltype = lf[:leave_type]

      scope = emp.leave_requests
      scope = scope.where(leave_type: ltype) if ltype.present?
      # Apply status filter only when explicitly requested; otherwise count all statuses
      if lf[:status].present?
        scope = scope.where(status: lf[:status])
      end
      if year
        scope = scope.where(
          "EXTRACT(YEAR FROM start_date) = ? OR EXTRACT(YEAR FROM end_date) = ?",
          year, year
        )
      end
      scope.sum(:days_count).to_f
    end

    def leave_type_for(emp)
      lf    = leave_filters
      ltype = lf[:leave_type]
      # If a specific type was requested, return it directly (no need to query)
      return ltype if ltype.present?

      year  = lf[:period_year]&.to_i
      scope = emp.leave_requests.where.not(status: 'rejected')
      scope = scope.where("EXTRACT(YEAR FROM start_date) = ? OR EXTRACT(YEAR FROM end_date) = ?", year, year) if year
      scope.distinct.pluck(:leave_type).join(', ').presence || "—"
    end

    def latest_evaluation_score(emp)
      eval = emp.evaluations.completed.order(completed_at: :desc).first
      eval&.score
    end

    def latest_evaluation_status(emp)
      eval = emp.evaluations.order(created_at: :desc).first
      eval&.status
    end

    def format_salary(emp)
      return "—" if emp.gross_salary_cents.to_i.zero?
      "#{emp.gross_salary.round(2)} €"
    end

    # ─── Filter accessors ───────────────────────────────────────────────────────

    def employee_filters
      @employee_filters ||= (filters[:employee] || {}).with_indifferent_access
    end

    def leave_filters
      @leave_filters ||= (filters[:leave] || {}).with_indifferent_access
    end

    def evaluation_filters
      @evaluation_filters ||= (filters[:evaluation] || {}).with_indifferent_access
    end

    def onboarding_filters
      @onboarding_filters ||= (filters[:onboarding] || {}).with_indifferent_access
    end

    def one_on_one_filters
      @one_on_one_filters ||= (filters[:one_on_one] || {}).with_indifferent_access
    end

    def objective_filters
      @objective_filters ||= (filters[:objective] || {}).with_indifferent_access
    end

    def time_tracking_filters
      @time_tracking_filters ||= (filters[:time_tracking] || {}).with_indifferent_access
    end

    def training_filters
      @training_filters ||= (filters[:training] || {}).with_indifferent_access
    end

    def output_columns
      cols = Array(filters.dig(:output, :columns)).map(&:to_s).reject(&:blank?)
      cols = %w[name department contract_type] if cols.empty?

      # Salary column: only if explicitly requested AND only if LLM set include_salary true
      # The second Ruby-side check (can_see_salary) happens in build_rows
      include_salary = filters.dig(:output, :include_salary)
      cols.delete("salary") unless include_salary == true || include_salary == "true"
      cols
    end

    def any_present?(hash, *keys)
      keys.any? { |k| hash[k].present? }
    end
  end
end
