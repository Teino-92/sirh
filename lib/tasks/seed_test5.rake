# frozen_string_literal: true
# =============================================================================
# Seed massif pour l'organisation "test5" en production
# Usage : rails db:seed:test5
# Idempotent : find_or_create_by sur tous les objets clés
# =============================================================================

namespace :db do
  namespace :seed do
    desc "Seed massif pour l'organisation test5 (30 employés, règles, congés)"
    task test5: :environment do
      ActsAsTenant.without_tenant do

        puts "🏢 Organisation test5..."
        org = Organization.find_or_create_by!(name: "test 5") do |o|
          o.plan = "sirh"
          o.billing_model = "per_employee"
          o.settings = {
            "work_week_hours"    => 35,
            "cp_acquisition_rate" => 2.5,
            "cp_expiry_month"    => 5,
            "cp_expiry_day"      => 31,
            "rtt_enabled"        => true,
            "overtime_threshold" => 35,
            "max_daily_hours"    => 10,
            "rules_engine_enabled" => true,
            "group_policies" => {
              "manager_can_approve_leave"  => true,
              "auto_approve_leave_by_role" => { "employee" => false, "manager" => false }
            }
          }
        end

        # Active le rules engine si l'org existait déjà
        unless org.settings["rules_engine_enabled"]
          org.settings["rules_engine_enabled"] = true
          org.save!
        end

        # ─── Helpers ──────────────────────────────────────────────────────────

        def find_or_build_employee(org, email, attrs)
          emp = org.employees.find_by(email: email)
          return emp if emp
          org.employees.create!(attrs.merge(email: email, password: "password123"))
        end

        def upsert_balance(employee, leave_type, balance)
          lb = employee.leave_balances.find_or_initialize_by(leave_type: leave_type)
          lb.balance = balance
          lb.save!
          lb
        end

        puts "👑 C-suite..."

        ceo = find_or_build_employee(org, "ceo@test5.fr",
          first_name: "Sophie", last_name: "Marchand",
          role: "admin", department: "Direction", job_title: "CEO",
          contract_type: "CDI", start_date: 6.years.ago,
          gross_salary_cents: 1_300_000, employer_charges_rate: 1.45,
          settings: { "cadre" => true, "active" => true }
        )

        cto = find_or_build_employee(org, "cto@test5.fr",
          first_name: "Lucas", last_name: "Perrin",
          role: "admin", department: "Technique", job_title: "CTO",
          contract_type: "CDI", start_date: 5.years.ago, manager: ceo,
          gross_salary_cents: 1_100_000, employer_charges_rate: 1.45,
          settings: { "cadre" => true, "active" => true }
        )

        dhr = find_or_build_employee(org, "dhr@test5.fr",
          first_name: "Amandine", last_name: "Rousseau",
          role: "hr", department: "RH", job_title: "Directrice RH",
          contract_type: "CDI", start_date: 4.years.ago, manager: ceo,
          gross_salary_cents: 850_000, employer_charges_rate: 1.45,
          settings: { "cadre" => true, "active" => true }
        )

        puts "👔 Managers..."

        mgr_backend = find_or_build_employee(org, "mgr.backend@test5.fr",
          first_name: "Théo", last_name: "Girard",
          role: "manager", department: "Engineering", job_title: "Lead Backend",
          contract_type: "CDI", start_date: 3.years.ago, manager: cto,
          gross_salary_cents: 720_000, employer_charges_rate: 1.45,
          settings: { "cadre" => true, "active" => true }
        )

        mgr_frontend = find_or_build_employee(org, "mgr.frontend@test5.fr",
          first_name: "Camille", last_name: "Bertrand",
          role: "manager", department: "Engineering", job_title: "Lead Frontend",
          contract_type: "CDI", start_date: 3.years.ago, manager: cto,
          gross_salary_cents: 700_000, employer_charges_rate: 1.45,
          settings: { "cadre" => true, "active" => true }
        )

        mgr_product = find_or_build_employee(org, "mgr.product@test5.fr",
          first_name: "Juliette", last_name: "Faure",
          role: "manager", department: "Product", job_title: "Head of Product",
          contract_type: "CDI", start_date: 2.years.ago, manager: ceo,
          gross_salary_cents: 750_000, employer_charges_rate: 1.45,
          settings: { "cadre" => true, "active" => true }
        )

        mgr_sales = find_or_build_employee(org, "mgr.sales@test5.fr",
          first_name: "Hugo", last_name: "Lombard",
          role: "manager", department: "Commercial", job_title: "Directeur Commercial",
          contract_type: "CDI", start_date: 2.years.ago, manager: ceo,
          gross_salary_cents: 680_000, variable_pay_cents: 180_000, employer_charges_rate: 1.45,
          settings: { "cadre" => true, "active" => true }
        )

        mgr_devops = find_or_build_employee(org, "mgr.devops@test5.fr",
          first_name: "Nathan", last_name: "Simon",
          role: "manager", department: "Infra", job_title: "Lead DevOps",
          contract_type: "CDI", start_date: 3.years.ago, manager: cto,
          gross_salary_cents: 710_000, employer_charges_rate: 1.45,
          settings: { "cadre" => true, "active" => true }
        )

        puts "💼 RH..."

        rh1 = find_or_build_employee(org, "rh1@test5.fr",
          first_name: "Léa", last_name: "Morin",
          role: "hr", department: "RH", job_title: "RH Généraliste",
          contract_type: "CDI", start_date: 2.years.ago, manager: dhr,
          gross_salary_cents: 420_000, employer_charges_rate: 1.35,
          settings: { "cadre" => false, "active" => true }
        )

        puts "👨‍💻 Backend team..."

        backend_devs = [
          ["dev.b1@test5.fr", "Alexis",  "Dumont",   "Senior Developer",    580_000, 4.years.ago],
          ["dev.b2@test5.fr", "Emma",    "Leclerc",  "Développeuse Backend", 520_000, 2.years.ago],
          ["dev.b3@test5.fr", "Pierre",  "Renaud",   "Développeur Backend",  480_000, 1.year.ago],
          ["dev.b4@test5.fr", "Yasmine", "Khalil",   "Développeuse Backend", 490_000, 18.months.ago],
          ["dev.b5@test5.fr", "Romain",  "Clement",  "Junior Developer",     380_000, 6.months.ago],
        ]

        backend_team = backend_devs.map do |email, first, last, title, salary, start|
          find_or_build_employee(org, email,
            first_name: first, last_name: last, role: "employee",
            department: "Engineering", job_title: title,
            contract_type: "CDI", start_date: start, manager: mgr_backend,
            gross_salary_cents: salary, employer_charges_rate: 1.35,
            settings: { "cadre" => true, "active" => true }
          )
        end

        puts "🎨 Frontend team..."

        frontend_devs = [
          ["dev.f1@test5.fr", "Marie",    "Leroy",   "Senior Frontend",     560_000, 3.years.ago],
          ["dev.f2@test5.fr", "Antoine",  "Blanc",   "Développeur React",   490_000, 2.years.ago],
          ["dev.f3@test5.fr", "Chloé",    "Henry",   "Développeuse Vue.js", 470_000, 1.year.ago],
          ["dev.f4@test5.fr", "Baptiste", "Martin",  "Intégrateur Web",     400_000, 8.months.ago],
        ]

        frontend_team = frontend_devs.map do |email, first, last, title, salary, start|
          find_or_build_employee(org, email,
            first_name: first, last_name: last, role: "employee",
            department: "Engineering", job_title: title,
            contract_type: "CDI", start_date: start, manager: mgr_frontend,
            gross_salary_cents: salary, employer_charges_rate: 1.35,
            settings: { "cadre" => true, "active" => true }
          )
        end

        puts "🚀 DevOps team..."

        devops_team = [
          ["devops1@test5.fr", "Valentin", "Lecomte", "Senior DevOps",  620_000, 3.years.ago],
          ["devops2@test5.fr", "Inès",     "Barbier", "SRE Engineer",   580_000, 2.years.ago],
          ["devops3@test5.fr", "Florian",  "Dupuis",  "Cloud Engineer", 540_000, 1.year.ago],
        ].map do |email, first, last, title, salary, start|
          find_or_build_employee(org, email,
            first_name: first, last_name: last, role: "employee",
            department: "Infra", job_title: title,
            contract_type: "CDI", start_date: start, manager: mgr_devops,
            gross_salary_cents: salary, employer_charges_rate: 1.35,
            settings: { "cadre" => true, "active" => true }
          )
        end

        puts "📦 Product team..."

        product_team = [
          ["pm1@test5.fr", "Sarah",   "Petit",    "Product Manager",  620_000, 3.years.ago],
          ["pm2@test5.fr", "Adrien",  "Guerin",   "Product Manager",  580_000, 2.years.ago],
          ["pm3@test5.fr", "Manon",   "Legrand",  "Product Designer", 520_000, 1.year.ago],
        ].map do |email, first, last, title, salary, start|
          find_or_build_employee(org, email,
            first_name: first, last_name: last, role: "employee",
            department: "Product", job_title: title,
            contract_type: "CDI", start_date: start, manager: mgr_product,
            gross_salary_cents: salary, employer_charges_rate: 1.35,
            settings: { "cadre" => true, "active" => true }
          )
        end

        puts "💰 Sales team..."

        sales_team = [
          ["sales1@test5.fr", "Thomas",  "Fournier", "Account Executive", 460_000, 2.years.ago],
          ["sales2@test5.fr", "Pauline", "Michel",   "Account Executive", 440_000, 1.year.ago],
          ["sales3@test5.fr", "Kevin",   "Robert",   "SDR",               360_000, 6.months.ago],
          ["sales4@test5.fr", "Clara",   "David",    "SDR",               350_000, 3.months.ago],
        ].map do |email, first, last, title, salary, start|
          find_or_build_employee(org, email,
            first_name: first, last_name: last, role: "employee",
            department: "Commercial", job_title: title,
            contract_type: "CDI", start_date: start, manager: mgr_sales,
            gross_salary_cents: salary, variable_pay_cents: 80_000, employer_charges_rate: 1.35,
            settings: { "cadre" => false, "active" => true }
          )
        end

        all_employees = [ceo, cto, dhr, mgr_backend, mgr_frontend, mgr_product, mgr_sales, mgr_devops, rh1] +
                        backend_team + frontend_team + devops_team + product_team + sales_team

        puts "📊 Leave balances (#{all_employees.size} employés)..."

        all_employees.each do |emp|
          upsert_balance(emp, "CP",  rand(8..25).to_f)
          upsert_balance(emp, "RTT", rand(0..8).to_f)
          upsert_balance(emp, "Maladie", 0.0)
        end

        puts "🗓️  Leave requests variées..."

        leave_scenarios = [
          # [employee, leave_type, start_offset_days, duration, status, approver]
          [backend_team[0],  "CP",      -30, 5,  "approved",  mgr_backend],
          [backend_team[1],  "RTT",     -15, 2,  "approved",  mgr_backend],
          [backend_team[2],  "CP",       10, 10, "pending",   nil],
          [backend_team[3],  "CP",      -60, 7,  "approved",  mgr_backend],
          [backend_team[4],  "RTT",       5, 1,  "pending",   nil],
          [frontend_team[0], "CP",      -45, 5,  "approved",  mgr_frontend],
          [frontend_team[1], "RTT",     -10, 2,  "approved",  mgr_frontend],
          [frontend_team[2], "CP",       20, 5,  "pending",   nil],
          [frontend_team[3], "CP",      -90, 14, "approved",  mgr_frontend],
          [devops_team[0],   "CP",      -20, 5,  "approved",  mgr_devops],
          [devops_team[1],   "RTT",       3, 1,  "pending",   nil],
          [devops_team[2],   "CP",      -50, 5,  "approved",  mgr_devops],
          [product_team[0],  "CP",      -35, 5,  "approved",  mgr_product],
          [product_team[1],  "RTT",     -5,  2,  "approved",  mgr_product],
          [product_team[2],  "CP",       15, 5,  "pending",   nil],
          [sales_team[0],    "CP",      -25, 5,  "approved",  mgr_sales],
          [sales_team[1],    "RTT",     -8,  1,  "approved",  mgr_sales],
          [sales_team[2],    "CP",       7,  3,  "pending",   nil],
          [sales_team[3],    "CP",       30, 5,  "pending",   nil],
          [rh1,              "CP",      -40, 10, "approved",  dhr],
          [mgr_backend,      "CP",      -70, 5,  "approved",  cto],
          [mgr_frontend,     "RTT",     -12, 2,  "approved",  cto],
          [mgr_product,      "CP",       25, 7,  "pending",   nil],
          [mgr_sales,        "CP",      -55, 5,  "approved",  ceo],
          [mgr_devops,       "RTT",     -3,  1,  "approved",  cto],
          [backend_team[0],  "CP",       40, 5,  "pending",   nil],
          [frontend_team[0], "RTT",     -2,  1,  "rejected",  mgr_frontend],
          [devops_team[0],   "CP",      -100, 3, "rejected",  mgr_devops],
          [product_team[0],  "RTT",      50, 2,  "pending",   nil],
          [sales_team[0],    "CP",      -80, 3,  "approved",  mgr_sales],
        ]

        leave_scenarios.each_with_index do |(emp, type, offset, duration, status, approver), i|
          start_date = Date.current + offset.days
          end_date   = start_date + duration.days - 1

          # Idempotence : skip si une demande similaire existe déjà
          next if org.leave_requests.exists?(
            employee: emp, leave_type: type,
            start_date: start_date, end_date: end_date
          )

          lr = org.leave_requests.create!(
            employee: emp,
            leave_type: type,
            start_date: start_date,
            end_date: end_date,
            days_count: duration.to_f,
            status: "pending",
            notes: ["Vacances planifiées", "RTT posé", "Congés famille", "Repos"].sample
          )

          case status
          when "approved"
            lr.update!(
              status: "approved",
              approved_by: approver,
              approved_at: (start_date - rand(1..5).days).to_time
            )
          when "rejected"
            lr.update!(
              status: "rejected",
              approved_by: approver,
              approved_at: (Date.current - rand(1..3).days).to_time,
              rejection_reason: ["Période chargée", "Équipe sous-staffée", "Conflit planning"].sample
            )
          end
        end

        puts "⚙️  Business rules..."

        rules_data = [
          {
            name: "Approbation manager pour CP > 5 jours",
            trigger: "leave_request.submitted",
            conditions: [
              { "field" => "days_count", "operator" => "gt", "value" => 5 },
              { "field" => "leave_type", "operator" => "eq", "value" => "CP" }
            ],
            actions: [
              { "type" => "require_approval", "role" => "manager", "order" => 1 }
            ],
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
            description: "Les congés longs (10 j+) requièrent manager puis RH"
          },
          {
            name: "Auto-approbation RTT ≤ 2 jours",
            trigger: "leave_request.submitted",
            conditions: [
              { "field" => "leave_type", "operator" => "eq",  "value" => "RTT" },
              { "field" => "days_count", "operator" => "lte", "value" => 2 }
            ],
            actions: [
              { "type" => "auto_approve" }
            ],
            priority: 1,
            description: "Les RTT courts sont auto-approuvés sans validation"
          },
          {
            name: "Escalade si manager ne répond pas sous 48h",
            trigger: "leave_request.submitted",
            conditions: [
              { "field" => "days_count", "operator" => "gte", "value" => 5 }
            ],
            actions: [
              {
                "type"             => "escalate_after",
                "role"             => "manager",
                "order"            => 1,
                "hours"            => 48,
                "escalate_to_role" => "hr"
              }
            ],
            priority: 20,
            description: "Si le manager n'approuve pas dans 48h, escalade vers RH automatiquement"
          },
          {
            name: "Notification RH sur rejet de congés",
            trigger: "leave_request.rejected",
            conditions: [],
            actions: [
              {
                "type"    => "notify",
                "role"    => "hr",
                "subject" => "Congé refusé",
                "message" => "Une demande de congé a été refusée. Vérifiez si un suivi est nécessaire."
              }
            ],
            priority: 1,
            description: "Informe les RH de chaque refus de congé pour suivi éventuel"
          },
          {
            name: "Bloquer congé pendant période critique",
            trigger: "leave_request.submitted",
            conditions: [
              { "field" => "leave_type", "operator" => "in", "value" => %w[CP RTT] }
            ],
            actions: [
              {
                "type"   => "block",
                "reason" => "Règle test : dépôt bloqué — à désactiver après test"
              }
            ],
            priority: 100,
            active: false,  # désactivée par défaut, pour test
            description: "[TEST] Règle de blocage total — active la pour tester l'action block"
          }
        ]

        rules_data.each do |attrs|
          next if org.business_rules.exists?(name: attrs[:name])
          org.business_rules.create!(
            name:        attrs[:name],
            trigger:     attrs[:trigger],
            conditions:  attrs[:conditions],
            actions:     attrs[:actions],
            priority:    attrs[:priority],
            active:      attrs.fetch(:active, true),
            description: attrs[:description]
          )
        end

        puts ""
        puts "✅ Seed test5 terminé !"
        puts "   Organisation : #{org.name} (id=#{org.id})"
        puts "   Employés     : #{org.employees.count}"
        puts "   Leave requests: #{org.leave_requests.count}"
        puts "   Business rules: #{org.business_rules.count}"
        puts ""
        puts "🔐 Comptes :"
        puts "   Admin  → ceo@test5.fr / password123"
        puts "   DRH    → dhr@test5.fr / password123"
        puts "   Manager → mgr.backend@test5.fr / password123"
        puts ""

      end
    end
  end
end
