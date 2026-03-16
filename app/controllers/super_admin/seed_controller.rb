# frozen_string_literal: true

module SuperAdmin
  class SeedController < ActionController::Base
    http_basic_authenticate_with(
      name:     ENV.fetch('SUPER_ADMIN_LOGIN',    'matteo'),
      password: ENV.fetch('SUPER_ADMIN_PASSWORD', 'changeme')
    )
    skip_before_action :verify_authenticity_token

    layout false

    def test5
      ActsAsTenant.without_tenant do
        org = Organization.find_or_create_by!(name: "test 5") do |o|
          o.plan          = "sirh"
          o.billing_model = "per_employee"
          o.settings      = default_settings
        end

        unless org.settings["rules_engine_enabled"]
          org.settings["rules_engine_enabled"] = true
          org.save!
        end

        @stats = { employees_before: org.employees.count }

        seed_employees(org)
        seed_leave_requests(org)
        seed_business_rules(org)

        @stats[:employees_after]     = org.employees.count
        @stats[:leave_requests]      = org.leave_requests.count
        @stats[:business_rules]      = org.business_rules.count
        @stats[:org_id]              = org.id
      end

      render :test5
    end

    private

    def default_settings
      {
        "work_week_hours"       => 35,
        "cp_acquisition_rate"   => 2.5,
        "cp_expiry_month"       => 5,
        "cp_expiry_day"         => 31,
        "rtt_enabled"           => true,
        "overtime_threshold"    => 35,
        "max_daily_hours"       => 10,
        "rules_engine_enabled"  => true,
        "group_policies" => {
          "manager_can_approve_leave"  => true,
          "auto_approve_leave_by_role" => { "employee" => false, "manager" => false }
        }
      }
    end

    def find_or_build(org, email, attrs)
      org.employees.find_by(email: email) ||
        org.employees.create!(attrs.merge(email: email, password: "password123"))
    end

    def upsert_balance(employee, leave_type, balance)
      lb = employee.leave_balances.find_or_initialize_by(leave_type: leave_type)
      lb.balance = balance
      lb.save!
    end

    def seed_employees(org)
      ceo = find_or_build(org, "ceo@test5.fr",
        first_name: "Sophie", last_name: "Marchand", role: "admin",
        department: "Direction", job_title: "CEO", contract_type: "CDI",
        start_date: 6.years.ago, gross_salary_cents: 1_300_000,
        employer_charges_rate: 1.45, settings: { "cadre" => true, "active" => true })

      cto = find_or_build(org, "cto@test5.fr",
        first_name: "Lucas", last_name: "Perrin", role: "admin",
        department: "Technique", job_title: "CTO", contract_type: "CDI",
        start_date: 5.years.ago, manager: ceo, gross_salary_cents: 1_100_000,
        employer_charges_rate: 1.45, settings: { "cadre" => true, "active" => true })

      dhr = find_or_build(org, "dhr@test5.fr",
        first_name: "Amandine", last_name: "Rousseau", role: "hr",
        department: "RH", job_title: "Directrice RH", contract_type: "CDI",
        start_date: 4.years.ago, manager: ceo, gross_salary_cents: 850_000,
        employer_charges_rate: 1.45, settings: { "cadre" => true, "active" => true })

      mgr_b = find_or_build(org, "mgr.backend@test5.fr",
        first_name: "Théo", last_name: "Girard", role: "manager",
        department: "Engineering", job_title: "Lead Backend", contract_type: "CDI",
        start_date: 3.years.ago, manager: cto, gross_salary_cents: 720_000,
        employer_charges_rate: 1.45, settings: { "cadre" => true, "active" => true })

      mgr_f = find_or_build(org, "mgr.frontend@test5.fr",
        first_name: "Camille", last_name: "Bertrand", role: "manager",
        department: "Engineering", job_title: "Lead Frontend", contract_type: "CDI",
        start_date: 3.years.ago, manager: cto, gross_salary_cents: 700_000,
        employer_charges_rate: 1.45, settings: { "cadre" => true, "active" => true })

      mgr_p = find_or_build(org, "mgr.product@test5.fr",
        first_name: "Juliette", last_name: "Faure", role: "manager",
        department: "Product", job_title: "Head of Product", contract_type: "CDI",
        start_date: 2.years.ago, manager: ceo, gross_salary_cents: 750_000,
        employer_charges_rate: 1.45, settings: { "cadre" => true, "active" => true })

      mgr_s = find_or_build(org, "mgr.sales@test5.fr",
        first_name: "Hugo", last_name: "Lombard", role: "manager",
        department: "Commercial", job_title: "Directeur Commercial", contract_type: "CDI",
        start_date: 2.years.ago, manager: ceo, gross_salary_cents: 680_000,
        variable_pay_cents: 180_000, employer_charges_rate: 1.45,
        settings: { "cadre" => true, "active" => true })

      mgr_d = find_or_build(org, "mgr.devops@test5.fr",
        first_name: "Nathan", last_name: "Simon", role: "manager",
        department: "Infra", job_title: "Lead DevOps", contract_type: "CDI",
        start_date: 3.years.ago, manager: cto, gross_salary_cents: 710_000,
        employer_charges_rate: 1.45, settings: { "cadre" => true, "active" => true })

      rh1 = find_or_build(org, "rh1@test5.fr",
        first_name: "Léa", last_name: "Morin", role: "hr",
        department: "RH", job_title: "RH Généraliste", contract_type: "CDI",
        start_date: 2.years.ago, manager: dhr, gross_salary_cents: 420_000,
        employer_charges_rate: 1.35, settings: { "cadre" => false, "active" => true })

      [
        ["dev.b1@test5.fr", "Alexis",  "Dumont",   "Senior Developer",     580_000, 4.years.ago,  mgr_b],
        ["dev.b2@test5.fr", "Emma",    "Leclerc",  "Développeuse Backend", 520_000, 2.years.ago,  mgr_b],
        ["dev.b3@test5.fr", "Pierre",  "Renaud",   "Développeur Backend",  480_000, 1.year.ago,   mgr_b],
        ["dev.b4@test5.fr", "Yasmine", "Khalil",   "Développeuse Backend", 490_000, 18.months.ago, mgr_b],
        ["dev.b5@test5.fr", "Romain",  "Clement",  "Junior Developer",     380_000, 6.months.ago, mgr_b],
        ["dev.f1@test5.fr", "Marie",   "Leroy",    "Senior Frontend",      560_000, 3.years.ago,  mgr_f],
        ["dev.f2@test5.fr", "Antoine", "Blanc",    "Développeur React",    490_000, 2.years.ago,  mgr_f],
        ["dev.f3@test5.fr", "Chloé",   "Henry",    "Développeuse Vue.js",  470_000, 1.year.ago,   mgr_f],
        ["dev.f4@test5.fr", "Baptiste","Martin",   "Intégrateur Web",      400_000, 8.months.ago, mgr_f],
        ["devops1@test5.fr","Valentin","Lecomte",  "Senior DevOps",        620_000, 3.years.ago,  mgr_d],
        ["devops2@test5.fr","Inès",    "Barbier",  "SRE Engineer",         580_000, 2.years.ago,  mgr_d],
        ["devops3@test5.fr","Florian", "Dupuis",   "Cloud Engineer",       540_000, 1.year.ago,   mgr_d],
        ["pm1@test5.fr",    "Sarah",   "Petit",    "Product Manager",      620_000, 3.years.ago,  mgr_p],
        ["pm2@test5.fr",    "Adrien",  "Guerin",   "Product Manager",      580_000, 2.years.ago,  mgr_p],
        ["pm3@test5.fr",    "Manon",   "Legrand",  "Product Designer",     520_000, 1.year.ago,   mgr_p],
        ["sales1@test5.fr", "Thomas",  "Fournier", "Account Executive",    460_000, 2.years.ago,  mgr_s],
        ["sales2@test5.fr", "Pauline", "Michel",   "Account Executive",    440_000, 1.year.ago,   mgr_s],
        ["sales3@test5.fr", "Kevin",   "Robert",   "SDR",                  360_000, 6.months.ago, mgr_s],
        ["sales4@test5.fr", "Clara",   "David",    "SDR",                  350_000, 3.months.ago, mgr_s],
      ].each do |email, first, last, title, salary, start, mgr|
        emp = find_or_build(org, email,
          first_name: first, last_name: last, role: "employee",
          department: mgr.department, job_title: title, contract_type: "CDI",
          start_date: start, manager: mgr, gross_salary_cents: salary,
          employer_charges_rate: 1.35, settings: { "cadre" => true, "active" => true })
        upsert_balance(emp, "CP",  rand(8..25).to_f)
        upsert_balance(emp, "RTT", rand(0..8).to_f)
      end

      [ceo, cto, dhr, mgr_b, mgr_f, mgr_p, mgr_s, mgr_d, rh1].each do |emp|
        upsert_balance(emp, "CP",  rand(10..25).to_f)
        upsert_balance(emp, "RTT", rand(2..10).to_f)
      end
    end

    def seed_leave_requests(org)
      scenarios = [
        ["dev.b1@test5.fr",      "CP",  -30, 5,  "approved", "mgr.backend@test5.fr"],
        ["dev.b2@test5.fr",      "RTT", -15, 2,  "approved", "mgr.backend@test5.fr"],
        ["dev.b3@test5.fr",      "CP",   10, 10, "pending",  nil],
        ["dev.b4@test5.fr",      "CP",  -60, 7,  "approved", "mgr.backend@test5.fr"],
        ["dev.b5@test5.fr",      "RTT",  5,  1,  "pending",  nil],
        ["dev.f1@test5.fr",      "CP",  -45, 5,  "approved", "mgr.frontend@test5.fr"],
        ["dev.f2@test5.fr",      "RTT", -10, 2,  "approved", "mgr.frontend@test5.fr"],
        ["dev.f3@test5.fr",      "CP",   20, 5,  "pending",  nil],
        ["dev.f4@test5.fr",      "CP",  -90, 14, "approved", "mgr.frontend@test5.fr"],
        ["devops1@test5.fr",     "CP",  -20, 5,  "approved", "mgr.devops@test5.fr"],
        ["devops2@test5.fr",     "RTT",  3,  1,  "pending",  nil],
        ["devops3@test5.fr",     "CP",  -50, 5,  "approved", "mgr.devops@test5.fr"],
        ["pm1@test5.fr",         "CP",  -35, 5,  "approved", "mgr.product@test5.fr"],
        ["pm2@test5.fr",         "RTT", -5,  2,  "approved", "mgr.product@test5.fr"],
        ["pm3@test5.fr",         "CP",   15, 5,  "pending",  nil],
        ["sales1@test5.fr",      "CP",  -25, 5,  "approved", "mgr.sales@test5.fr"],
        ["sales2@test5.fr",      "RTT", -8,  1,  "approved", "mgr.sales@test5.fr"],
        ["sales3@test5.fr",      "CP",   7,  3,  "pending",  nil],
        ["sales4@test5.fr",      "CP",   30, 5,  "pending",  nil],
        ["rh1@test5.fr",         "CP",  -40, 10, "approved", "dhr@test5.fr"],
        ["mgr.backend@test5.fr", "CP",  -70, 5,  "approved", "cto@test5.fr"],
        ["mgr.frontend@test5.fr","RTT", -12, 2,  "approved", "cto@test5.fr"],
        ["mgr.product@test5.fr", "CP",   25, 7,  "pending",  nil],
        ["mgr.sales@test5.fr",   "CP",  -55, 5,  "approved", "ceo@test5.fr"],
        ["mgr.devops@test5.fr",  "RTT", -3,  1,  "approved", "cto@test5.fr"],
        ["dev.b1@test5.fr",      "CP",   40, 5,  "pending",  nil],
        ["dev.f1@test5.fr",      "RTT", -2,  1,  "rejected", "mgr.frontend@test5.fr"],
        ["devops1@test5.fr",     "CP",  -100,3,  "rejected", "mgr.devops@test5.fr"],
        ["pm1@test5.fr",         "RTT",  50, 2,  "pending",  nil],
        ["sales1@test5.fr",      "CP",  -80, 3,  "approved", "mgr.sales@test5.fr"],
      ]

      scenarios.each do |emp_email, type, offset, duration, status, approver_email|
        emp      = org.employees.find_by!(email: emp_email)
        start_d  = Date.current + offset.days
        end_d    = start_d + duration.days - 1

        next if org.leave_requests.exists?(
          employee: emp, leave_type: type, start_date: start_d, end_date: end_d
        )

        lr = org.leave_requests.create!(
          employee: emp, leave_type: type,
          start_date: start_d, end_date: end_d,
          days_count: duration.to_f, status: "pending",
          notes: ["Vacances planifiées", "RTT posé", "Congés famille", "Repos"].sample
        )

        approver = approver_email ? org.employees.find_by(email: approver_email) : nil

        case status
        when "approved"
          lr.update!(status: "approved", approved_by: approver,
                     approved_at: (start_d - rand(1..5).days).to_time)
        when "rejected"
          lr.update!(status: "rejected", approved_by: approver,
                     approved_at: (Date.current - rand(1..3).days).to_time,
                     rejection_reason: ["Période chargée", "Équipe sous-staffée", "Conflit planning"].sample)
        end
      end
    end

    def seed_business_rules(org)
      [
        {
          name: "Approbation manager pour CP > 5 jours",
          trigger: "leave_request.submitted",
          conditions: [
            { "field" => "days_count", "operator" => "gt",  "value" => 5 },
            { "field" => "leave_type", "operator" => "eq",  "value" => "CP" }
          ],
          actions: [{ "type" => "require_approval", "role" => "manager", "order" => 1 }],
          priority: 10,
          description: "Toute demande CP de plus de 5 jours nécessite l'accord du manager"
        },
        {
          name: "Double validation manager + RH pour CP ≥ 10 jours",
          trigger: "leave_request.submitted",
          conditions: [
            { "field" => "days_count", "operator" => "gte", "value" => 10 },
            { "field" => "leave_type", "operator" => "eq",  "value" => "CP" }
          ],
          actions: [
            { "type" => "require_approval", "role" => "manager", "order" => 1 },
            { "type" => "require_approval", "role" => "hr",      "order" => 2 }
          ],
          priority: 5,
          description: "Les congés longs (10j+) requièrent manager puis RH"
        },
        {
          name: "Auto-approbation RTT ≤ 2 jours",
          trigger: "leave_request.submitted",
          conditions: [
            { "field" => "leave_type", "operator" => "eq",  "value" => "RTT" },
            { "field" => "days_count", "operator" => "lte", "value" => 2 }
          ],
          actions: [{ "type" => "auto_approve" }],
          priority: 1,
          description: "Les RTT courts sont auto-approuvés sans validation"
        },
        {
          name: "Escalade si manager ne répond pas sous 48h",
          trigger: "leave_request.submitted",
          conditions: [{ "field" => "days_count", "operator" => "gte", "value" => 5 }],
          actions: [{
            "type" => "escalate_after", "role" => "manager", "order" => 1,
            "hours" => 48, "escalate_to_role" => "hr"
          }],
          priority: 20,
          description: "Si le manager n'approuve pas dans 48h, escalade vers RH"
        },
        {
          name: "Notification RH sur rejet de congés",
          trigger: "leave_request.rejected",
          conditions: [],
          actions: [{
            "type" => "notify", "role" => "hr",
            "subject" => "Congé refusé",
            "message" => "Une demande de congé a été refusée. Vérifiez si un suivi est nécessaire."
          }],
          priority: 1,
          description: "Informe les RH de chaque refus pour suivi éventuel"
        },
        {
          name: "[TEST] Blocage total — désactivé",
          trigger: "leave_request.submitted",
          conditions: [{ "field" => "leave_type", "operator" => "in", "value" => %w[CP RTT] }],
          actions: [{ "type" => "block", "reason" => "Règle test — active pour tester le blocage" }],
          priority: 100,
          active: false,
          description: "Règle de test désactivée — active pour vérifier l'action block"
        }
      ].each do |attrs|
        next if org.business_rules.exists?(name: attrs[:name])
        org.business_rules.create!(
          name: attrs[:name], trigger: attrs[:trigger],
          conditions: attrs[:conditions], actions: attrs[:actions],
          priority: attrs[:priority], active: attrs.fetch(:active, true),
          description: attrs[:description]
        )
      end
    end
  end
end
