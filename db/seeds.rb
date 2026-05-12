# frozen_string_literal: true
# =============================================================================
# TechCorp France — Seed de démonstration
# 48 employés : comité de direction, managers, équipes, tous les scénarios RH
# =============================================================================

ActsAsTenant.without_tenant do

# ─── Helpers ─────────────────────────────────────────────────────────────────

def wdays(start_time, end_time, days = %w[monday tuesday wednesday thursday friday])
  days.each_with_object({}) { |d, h| h[d] = "#{start_time}-#{end_time}" }
end

def business_days_between(d1, d2)
  (d1..d2).count { |d| !d.saturday? && !d.sunday? }
end

def next_monday(offset_weeks = 0)
  today = Date.current
  monday = today + ((1 - today.wday) % 7).days
  monday += 7.days if today == monday # already monday → next week
  monday + (offset_weeks * 7).days
end

puts "🧹 Clearing existing data..."
[
  OnboardingTask, OnboardingReview, EmployeeOnboarding, OnboardingTemplateTask, OnboardingTemplate,
  TrainingAssignment, Training,
  ActionItem, Evaluation, OneOnOne, Objective,
  TimeEntry, LeaveRequest, LeaveBalance, WeeklySchedulePlan, WorkSchedule,
  Notification, Employee, Organization
].each(&:destroy_all)

# ─── Organisation ─────────────────────────────────────────────────────────────

puts "🏢 Creating organization..."
org = Organization.create!(
  name: "TechCorp France",
  settings: {
    work_week_hours: 35,
    cp_acquisition_rate: 2.5,
    rtt_enabled: true,
    overtime_threshold: 35,
    rules_engine_enabled: true,
    group_policies: {
      "manager_can_approve_leave" => true,
      "auto_approve_leave_by_role" => { "employee" => false, "manager" => false }
    }
  }
)

# ─── Comité de direction (tous admin/hr, tous cadres) ────────────────────────

puts "👑 Creating C-suite..."

ceo = org.employees.create!(
  email: "admin@techcorp.fr", password: "password123",
  first_name: "Alexandre", last_name: "Fontaine",
  role: "admin", department: "Direction Générale", job_title: "CEO",
  contract_type: "CDI", start_date: 5.years.ago,
  phone: "+33 6 10 00 00 01", address: "12 rue de la Paix, 75001 Paris",
  gross_salary_cents: 1200000, variable_pay_cents: 300000,
  employer_charges_rate: 1.45,
  settings: { "cadre" => true, "active" => true }
)

coo = org.employees.create!(
  email: "isabelle.moreau@techcorp.fr", password: "password123",
  first_name: "Isabelle", last_name: "Moreau",
  role: "admin", department: "Direction Générale", job_title: "COO",
  contract_type: "CDI", start_date: 4.years.ago, manager: ceo,
  phone: "+33 6 10 00 00 02", address: "45 avenue Victor Hugo, 75016 Paris",
  gross_salary_cents: 950000, variable_pay_cents: 200000,
  employer_charges_rate: 1.45,
  settings: { "cadre" => true, "active" => true }
)

cto = org.employees.create!(
  email: "romain.blanchard@techcorp.fr", password: "password123",
  first_name: "Romain", last_name: "Blanchard",
  role: "admin", department: "Engineering", job_title: "CTO",
  contract_type: "CDI", start_date: 4.years.ago, manager: ceo,
  phone: "+33 6 10 00 00 03", address: "8 rue du Faubourg Saint-Antoine, 75012 Paris",
  gross_salary_cents: 900000, variable_pay_cents: 180000,
  employer_charges_rate: 1.45,
  settings: { "cadre" => true, "active" => true }
)

dhr = org.employees.create!(
  email: "nathalie.legrand@techcorp.fr", password: "password123",
  first_name: "Nathalie", last_name: "Legrand",
  role: "hr", department: "Ressources Humaines", job_title: "Directrice des Ressources Humaines",
  contract_type: "CDI", start_date: 3.years.ago, manager: coo,
  phone: "+33 6 10 00 00 04", address: "23 boulevard Haussmann, 75009 Paris",
  gross_salary_cents: 750000, variable_pay_cents: 100000,
  employer_charges_rate: 1.45,
  settings: { "cadre" => true, "active" => true }
)

# ─── Managers (tous cadres) ──────────────────────────────────────────────────

puts "👔 Creating managers..."

mgr_backend = org.employees.create!(
  email: "thomas.martin@techcorp.fr", password: "password123",
  first_name: "Thomas", last_name: "Martin",
  role: "manager", department: "Engineering", job_title: "Lead Backend Engineer",
  contract_type: "CDI", start_date: 3.years.ago, manager: cto,
  phone: "+33 6 20 00 00 01", address: "5 rue de Rennes, 75006 Paris",
  gross_salary_cents: 650000, variable_pay_cents: 80000,
  employer_charges_rate: 1.45,
  settings: { "cadre" => true, "active" => true }
)

mgr_frontend = org.employees.create!(
  email: "sophie.bernard@techcorp.fr", password: "password123",
  first_name: "Sophie", last_name: "Bernard",
  role: "manager", department: "Engineering", job_title: "Lead Frontend Engineer",
  contract_type: "CDI", start_date: 2.years.ago, manager: cto,
  phone: "+33 6 20 00 00 02", address: "18 rue du Temple, 75004 Paris",
  gross_salary_cents: 620000, variable_pay_cents: 70000,
  employer_charges_rate: 1.45,
  settings: { "cadre" => true, "active" => true }
)

mgr_sales = org.employees.create!(
  email: "pierre.dubois@techcorp.fr", password: "password123",
  first_name: "Pierre", last_name: "Dubois",
  role: "manager", department: "Sales", job_title: "Sales Manager",
  contract_type: "CDI", start_date: 2.years.ago.+(6.months), manager: coo,
  phone: "+33 6 20 00 00 03", address: "67 avenue des Champs-Élysées, 75008 Paris",
  gross_salary_cents: 580000, variable_pay_cents: 150000,
  employer_charges_rate: 1.45,
  settings: { "cadre" => true, "active" => true }
)

mgr_product = org.employees.create!(
  email: "clara.rousseau@techcorp.fr", password: "password123",
  first_name: "Clara", last_name: "Rousseau",
  role: "manager", department: "Product", job_title: "Product Manager Lead",
  contract_type: "CDI", start_date: 2.years.ago, manager: coo,
  phone: "+33 6 20 00 00 04", address: "9 rue Oberkampf, 75011 Paris",
  gross_salary_cents: 600000, variable_pay_cents: 80000,
  employer_charges_rate: 1.45,
  settings: { "cadre" => true, "active" => true }
)

mgr_devops = org.employees.create!(
  email: "mathieu.girard@techcorp.fr", password: "password123",
  first_name: "Mathieu", last_name: "Girard",
  role: "manager", department: "Engineering", job_title: "DevOps Manager",
  contract_type: "CDI", start_date: 18.months.ago, manager: cto,
  phone: "+33 6 20 00 00 05", address: "34 rue de la Roquette, 75011 Paris",
  gross_salary_cents: 630000, variable_pay_cents: 60000,
  employer_charges_rate: 1.45,
  settings: { "cadre" => true, "active" => true }
)

mgr_mktg = org.employees.create!(
  email: "aurelie.simon@techcorp.fr", password: "password123",
  first_name: "Aurélie", last_name: "Simon",
  role: "manager", department: "Marketing", job_title: "Head of Marketing",
  contract_type: "CDI", start_date: 2.years.ago, manager: coo,
  phone: "+33 6 20 00 00 06", address: "55 rue de Rivoli, 75001 Paris",
  gross_salary_cents: 560000, variable_pay_cents: 60000,
  employer_charges_rate: 1.45,
  settings: { "cadre" => true, "active" => true }
)

# ─── Équipe RH (non-cadres sauf DHR déjà créée) ─────────────────────────────

puts "📋 Creating HR team..."

hr_generalist = org.employees.create!(
  email: "camille.petit@techcorp.fr", password: "password123",
  first_name: "Camille", last_name: "Petit",
  role: "hr", department: "Ressources Humaines", job_title: "RH Généraliste",
  contract_type: "CDI", start_date: 2.years.ago, manager: dhr,
  phone: "+33 6 30 00 00 01", address: "12 rue Saint-Denis, 75001 Paris",
  gross_salary_cents: 380000, variable_pay_cents: 0,
  employer_charges_rate: 1.45,
  settings: { "cadre" => false, "active" => true }
)

hr_recruiter = org.employees.create!(
  email: "lea.simon@techcorp.fr", password: "password123",
  first_name: "Léa", last_name: "Simon",
  role: "hr", department: "Ressources Humaines", job_title: "Chargée de Recrutement",
  contract_type: "CDI", start_date: 14.months.ago, manager: dhr,
  phone: "+33 6 30 00 00 02", address: "7 passage de la Bonne Graine, 75011 Paris",
  gross_salary_cents: 350000, variable_pay_cents: 0,
  employer_charges_rate: 1.45,
  settings: { "cadre" => false, "active" => true }
)

# ─── Équipe Backend (sous mgr_backend) ──────────────────────────────────────

puts "💻 Creating Backend team..."

be_employees = [
  { email: "julien.leroy@techcorp.fr",   first_name: "Julien",   last_name: "Leroy",    job_title: "Développeur Backend Senior", contract: "CDI", start: 2.years.ago,    salary: 520000, var: 0 },
  { email: "hugo.lambert@techcorp.fr",   first_name: "Hugo",     last_name: "Lambert",  job_title: "Développeur Backend",        contract: "CDI", start: 18.months.ago,  salary: 460000, var: 0 },
  { email: "marie.chen@techcorp.fr",     first_name: "Marie",    last_name: "Chen",     job_title: "Développeuse Backend",       contract: "CDI", start: 1.year.ago,     salary: 440000, var: 0 },
  { email: "nicolas.david@techcorp.fr",  first_name: "Nicolas",  last_name: "David",    job_title: "Développeur Backend",        contract: "CDD", start: 8.months.ago,   salary: 380000, var: 0, end: 4.months.from_now },
  { email: "ana.ferreira@techcorp.fr",   first_name: "Ana",      last_name: "Ferreira", job_title: "Stagiaire Backend",          contract: "Stage", start: 3.months.ago, salary: 100000, var: 0, end: 3.months.from_now },
].map do |d|
  org.employees.create!(
    email: d[:email], password: "password123",
    first_name: d[:first_name], last_name: d[:last_name],
    role: "employee", department: "Engineering", job_title: d[:job_title],
    contract_type: d[:contract], start_date: d[:start], end_date: d[:end],
    manager: mgr_backend,
    gross_salary_cents: d[:salary], variable_pay_cents: d[:var],
    employer_charges_rate: 1.45,
    settings: { "cadre" => false, "active" => true }
  )
end

# ─── Équipe Frontend (sous mgr_frontend) ────────────────────────────────────

puts "🎨 Creating Frontend team..."

fe_employees = [
  { email: "emma.morel@techcorp.fr",     first_name: "Emma",    last_name: "Morel",    job_title: "Développeuse Frontend Senior", contract: "CDI",  start: 2.years.ago,   salary: 490000, var: 0 },
  { email: "lucas.fontaine@techcorp.fr", first_name: "Lucas",   last_name: "Fontaine", job_title: "Développeur React",            contract: "CDI",  start: 20.months.ago, salary: 450000, var: 0 },
  { email: "chloe.martin@techcorp.fr",   first_name: "Chloé",   last_name: "Martin",   job_title: "Développeuse Vue.js",          contract: "CDI",  start: 1.year.ago,    salary: 420000, var: 0 },
  { email: "yanis.benali@techcorp.fr",   first_name: "Yanis",   last_name: "Benali",   job_title: "Alternant Frontend",           contract: "Alternance", start: 9.months.ago, salary: 150000, var: 0, end: 3.months.from_now },
].map do |d|
  org.employees.create!(
    email: d[:email], password: "password123",
    first_name: d[:first_name], last_name: d[:last_name],
    role: "employee", department: "Engineering", job_title: d[:job_title],
    contract_type: d[:contract], start_date: d[:start], end_date: d[:end],
    manager: mgr_frontend,
    gross_salary_cents: d[:salary], variable_pay_cents: d[:var],
    employer_charges_rate: 1.45,
    settings: { "cadre" => false, "active" => true }
  )
end

# ─── Équipe DevOps (sous mgr_devops) ────────────────────────────────────────

puts "⚙️  Creating DevOps team..."

devops_employees = [
  { email: "kevin.faure@techcorp.fr",    first_name: "Kevin",   last_name: "Faure",   job_title: "DevOps Engineer Senior", contract: "CDI",   start: 2.years.ago,  salary: 540000, var: 0 },
  { email: "pauline.roux@techcorp.fr",   first_name: "Pauline", last_name: "Roux",    job_title: "SRE Engineer",           contract: "CDI",   start: 15.months.ago, salary: 500000, var: 0 },
  { email: "theo.garcia@techcorp.fr",    first_name: "Théo",    last_name: "Garcia",  job_title: "DevOps Engineer",        contract: "CDI",   start: 10.months.ago, salary: 460000, var: 0 },
].map do |d|
  org.employees.create!(
    email: d[:email], password: "password123",
    first_name: d[:first_name], last_name: d[:last_name],
    role: "employee", department: "Engineering", job_title: d[:job_title],
    contract_type: d[:contract], start_date: d[:start],
    manager: mgr_devops,
    gross_salary_cents: d[:salary], variable_pay_cents: d[:var],
    employer_charges_rate: 1.45,
    settings: { "cadre" => false, "active" => true }
  )
end

# ─── Équipe Sales (sous mgr_sales) ──────────────────────────────────────────

puts "💰 Creating Sales team..."

sales_employees = [
  { email: "alice.dumont@techcorp.fr",   first_name: "Alice",   last_name: "Dumont",  job_title: "Account Executive Senior", contract: "CDI",  start: 2.years.ago,   salary: 430000, var: 120000 },
  { email: "baptiste.gros@techcorp.fr",  first_name: "Baptiste",last_name: "Gros",    job_title: "Account Executive",        contract: "CDI",  start: 16.months.ago, salary: 380000, var: 90000  },
  { email: "jade.perrin@techcorp.fr",    first_name: "Jade",    last_name: "Perrin",  job_title: "Sales Development Rep",    contract: "CDI",  start: 1.year.ago,    salary: 340000, var: 60000  },
  { email: "maxime.henry@techcorp.fr",   first_name: "Maxime",  last_name: "Henry",   job_title: "Sales Development Rep",    contract: "CDD",  start: 6.months.ago,  salary: 320000, var: 40000, end: 6.months.from_now },
  { email: "sarah.cohen@techcorp.fr",    first_name: "Sarah",   last_name: "Cohen",   job_title: "Business Developer",       contract: "CDI",  start: 8.months.ago,  salary: 360000, var: 80000  },
].map do |d|
  org.employees.create!(
    email: d[:email], password: "password123",
    first_name: d[:first_name], last_name: d[:last_name],
    role: "employee", department: "Sales", job_title: d[:job_title],
    contract_type: d[:contract], start_date: d[:start], end_date: d[:end],
    manager: mgr_sales,
    gross_salary_cents: d[:salary], variable_pay_cents: d[:var],
    employer_charges_rate: 1.45,
    settings: { "cadre" => false, "active" => true }
  )
end

# ─── Équipe Product (sous mgr_product) ───────────────────────────────────────

puts "📦 Creating Product team..."

product_employees = [
  { email: "manon.lefevre@techcorp.fr",  first_name: "Manon",  last_name: "Lefèvre",  job_title: "Product Owner Senior",   contract: "CDI",   start: 22.months.ago, salary: 510000, var: 40000 },
  { email: "florian.vidal@techcorp.fr",  first_name: "Florian",last_name: "Vidal",    job_title: "Product Owner",           contract: "CDI",   start: 1.year.ago,    salary: 470000, var: 30000 },
  { email: "zoe.mercier@techcorp.fr",    first_name: "Zoé",    last_name: "Mercier",  job_title: "UX Designer",             contract: "CDI",   start: 18.months.ago, salary: 420000, var: 0     },
  { email: "gabriel.morin@techcorp.fr",  first_name: "Gabriel",last_name: "Morin",    job_title: "UX/UI Designer",          contract: "CDI",   start: 14.months.ago, salary: 400000, var: 0     },
  { email: "elisa.brunet@techcorp.fr",   first_name: "Elisa",  last_name: "Brunet",   job_title: "Stagiaire UX",            contract: "Stage", start: 2.months.ago,  salary:  90000, var: 0,    end: 4.months.from_now },
].map do |d|
  org.employees.create!(
    email: d[:email], password: "password123",
    first_name: d[:first_name], last_name: d[:last_name],
    role: "employee", department: "Product", job_title: d[:job_title],
    contract_type: d[:contract], start_date: d[:start], end_date: d[:end],
    manager: mgr_product,
    gross_salary_cents: d[:salary], variable_pay_cents: d[:var],
    employer_charges_rate: 1.45,
    settings: { "cadre" => false, "active" => true }
  )
end

# ─── Équipe Marketing (sous mgr_mktg) ────────────────────────────────────────

puts "📣 Creating Marketing team..."

mktg_employees = [
  { email: "lucie.baron@techcorp.fr",    first_name: "Lucie",   last_name: "Baron",    job_title: "Content Manager",       contract: "CDI",   start: 20.months.ago,  salary: 390000, var: 0 },
  { email: "victor.renard@techcorp.fr",  first_name: "Victor",  last_name: "Renard",   job_title: "SEO & Growth",           contract: "CDI",   start: 14.months.ago,  salary: 370000, var: 0 },
  { email: "ines.noel@techcorp.fr",      first_name: "Inès",    last_name: "Noël",     job_title: "Social Media Manager",   contract: "CDI",   start: 1.year.ago,     salary: 350000, var: 0 },
  { email: "louis.dupont@techcorp.fr",   first_name: "Louis",   last_name: "Dupont",   job_title: "Chargé de Com.",         contract: "Alternance", start: 6.months.ago, salary: 140000, var: 0, end: 6.months.from_now },
].map do |d|
  org.employees.create!(
    email: d[:email], password: "password123",
    first_name: d[:first_name], last_name: d[:last_name],
    role: "employee", department: "Marketing", job_title: d[:job_title],
    contract_type: d[:contract], start_date: d[:start], end_date: d[:end],
    manager: mgr_mktg,
    gross_salary_cents: d[:salary], variable_pay_cents: d[:var],
    employer_charges_rate: 1.45,
    settings: { "cadre" => false, "active" => true }
  )
end

# ─── Référentiels pratiques ──────────────────────────────────────────────────

dir_team     = [ceo, coo, cto, dhr]
all_managers = [mgr_backend, mgr_frontend, mgr_devops, mgr_sales, mgr_product, mgr_mktg]
hr_team      = [hr_generalist, hr_recruiter]  # dhr already cadre
all_employees_non_cadre = be_employees + fe_employees + devops_employees +
                          sales_employees + product_employees + mktg_employees + hr_team
all_people   = dir_team + all_managers + all_employees_non_cadre

puts "  Created #{Employee.count} employees total"

# ─── Work Schedules ───────────────────────────────────────────────────────────

puts "📅 Creating work schedules..."

# C-suite + managers = cadre → no schedule (they don't clock in)
# Non-cadre employees get a schedule

# 35h standard for most
(be_employees + fe_employees + mktg_employees + hr_team).each do |emp|
  WorkSchedule.create_from_template(emp, 'full_time_35h')
end

# 39h for DevOps and senior sales
(devops_employees + [sales_employees[0], sales_employees[1]]).each do |emp|
  WorkSchedule.create_from_template(emp, 'full_time_39h')
end

# 35h for remaining sales and product
(sales_employees[2..] + product_employees).each do |emp|
  WorkSchedule.create_from_template(emp, 'full_time_35h')
end

puts "  Created #{WorkSchedule.count} work schedules"

# ─── Leave Balances ───────────────────────────────────────────────────────────

puts "🏖️  Initializing leave balances..."

all_people.each do |emp|
  months = ((Date.current - emp.start_date) / 30).to_i
  cp = [months * 2.5, 30].min

  LeaveBalance.create!(employee: emp, organization: org, leave_type: 'CP',
    balance: cp, accrued_this_year: cp, used_this_year: 0,
    expires_at: Date.new(Date.current.year + 1, 5, 31))

  LeaveBalance.create!(employee: emp, organization: org, leave_type: 'Maladie',
    balance: 0, accrued_this_year: 0, used_this_year: 0)

  # RTT for 39h employees
  ws = emp.work_schedule
  if ws&.rtt_eligible?
    LeaveBalance.create!(employee: emp, organization: org, leave_type: 'RTT',
      balance: 6.0, accrued_this_year: 6.0, used_this_year: 0)
  end
end

puts "  Created #{LeaveBalance.count} leave balances"

# ─── Weekly Schedule Plans (5 semaines à partir de maintenant) ───────────────

puts "📆 Creating weekly schedule plans..."

# Pattern variants for realism
SCHEDULE_35H = {
  'monday' => '09:00-17:00', 'tuesday' => '09:00-17:00',
  'wednesday' => '09:00-17:00', 'thursday' => '09:00-17:00', 'friday' => '09:00-17:00'
}.freeze

SCHEDULE_39H = {
  'monday' => '09:00-18:00', 'tuesday' => '09:00-18:00',
  'wednesday' => '09:00-18:00', 'thursday' => '09:00-18:00', 'friday' => '09:00-17:00'
}.freeze

SCHEDULE_FLEX = {
  'monday' => '08:30-17:30', 'tuesday' => '08:30-17:30',
  'wednesday' => '08:30-17:30', 'thursday' => '08:30-17:30', 'friday' => '08:30-16:30'
}.freeze

today        = Date.current
week0_start  = today - today.cwday + 1  # Monday of current week
plan_weeks   = (0..5).map { |i| week0_start + (i * 7).days }

non_cadre_with_schedule = all_employees_non_cadre.select { |e| e.work_schedule.present? }

non_cadre_with_schedule.each do |emp|
  ws = emp.work_schedule
  pattern = ws.weekly_hours >= 39 ? SCHEDULE_39H : SCHEDULE_35H

  plan_weeks.each do |ws_start|
    WeeklySchedulePlan.create!(
      employee: emp, organization: org,
      week_start_date: ws_start,
      schedule_pattern: pattern,
      notes: nil
    )
  end
end

puts "  Created #{WeeklySchedulePlan.count} weekly plans"

# ─── Time Entries (semaine en cours + 2 semaines passées) ────────────────────

puts "⏰ Creating time entries..."

non_cadre_with_schedule.each do |emp|
  # 2 semaines passées complètes
  (-2..-1).each do |week_offset|
    w_start = week0_start + (week_offset * 7).days
    (0..4).each do |d|
      day = w_start + d.days
      next if day > today
      ci = day.to_time + 9.hours
      co = ci + 8.hours
      TimeEntry.create!(
        employee: emp, organization: org,
        clock_in: ci, clock_out: co,
        duration_minutes: 480, manual_override: false
      )
    end
  end

  # Semaine courante : lundi jusqu'à hier (sauf absences planifiées)
  (0..4).each do |d|
    day = week0_start + d.days
    break if day >= today
    ci = day.to_time + 9.hours
    co = ci + 8.hours
    TimeEntry.create!(
      employee: emp, organization: org,
      clock_in: ci, clock_out: co,
      duration_minutes: 480, manual_override: false
    )
  end

  # Aujourd'hui : quelques employés sont pointés
  if [be_employees[0], fe_employees[0], devops_employees[0], sales_employees[0]].include?(emp)
    TimeEntry.create!(
      employee: emp, organization: org,
      clock_in: today.to_time + 9.hours,
      clock_out: nil, manual_override: false
    )
  end
end

puts "  Created #{TimeEntry.count} time entries"

# ─── Leave Requests — tous les scénarios ─────────────────────────────────────

puts "📝 Creating leave requests..."

# Pre-load sufficient balances for sick leave scenarios
# (In production, Maladie is tracked but not deducted from a capped pool —
#  here we seed a realistic initial balance so the validation passes)
[be_employees[2], mktg_employees[1], product_employees[1]].each do |emp|
  bal = LeaveBalance.find_by(employee: emp, leave_type: 'Maladie')
  bal&.update_columns(balance: 20.0, accrued_this_year: 20.0)
end

w1 = next_monday(0)  # semaine +1
w2 = next_monday(1)  # semaine +2
w3 = next_monday(2)  # semaine +3

# ── Congés approuvés (CP) ──────────────────────────────────────────────────

# Backend dev senior — 1 semaine de vacances
LeaveRequest.create!(
  employee: be_employees[0], organization: org, leave_type: 'CP',
  start_date: w1, end_date: w1 + 4.days, days_count: 5,
  status: 'approved', reason: "Vacances été",
  approved_by: mgr_backend, approved_at: 3.days.ago
)

# Frontend dev — long week-end
LeaveRequest.create!(
  employee: fe_employees[1], organization: org, leave_type: 'CP',
  start_date: w1 + 3.days, end_date: w1 + 4.days, days_count: 2,
  status: 'approved', reason: "Pont du jeudi",
  approved_by: mgr_frontend, approved_at: 1.week.ago
)

# Sales AE — 2 semaines
LeaveRequest.create!(
  employee: sales_employees[0], organization: org, leave_type: 'CP',
  start_date: w2, end_date: w2 + 9.days, days_count: 10,
  status: 'approved', reason: "Congés annuels",
  approved_by: mgr_sales, approved_at: 2.weeks.ago
)

# Product PO — RTT
ws_rtt = LeaveBalance.find_by(employee: product_employees[0], leave_type: 'RTT')
LeaveRequest.create!(
  employee: product_employees[0], organization: org, leave_type: 'RTT',
  start_date: w1 + 4.days, end_date: w1 + 4.days, days_count: 1,
  status: 'approved', reason: "RTT vendredi",
  approved_by: mgr_product, approved_at: 2.days.ago
) if ws_rtt

# DevOps senior — RTT
ws_rtt2 = LeaveBalance.find_by(employee: devops_employees[0], leave_type: 'RTT')
LeaveRequest.create!(
  employee: devops_employees[0], organization: org, leave_type: 'RTT',
  start_date: w2 + 1.days, end_date: w2 + 2.days, days_count: 2,
  status: 'approved', reason: "RTT DevOps sprint",
  approved_by: mgr_devops, approved_at: 1.week.ago
) if ws_rtt2

# ── Congés en attente ──────────────────────────────────────────────────────

# Marketing content — en attente
LeaveRequest.create!(
  employee: mktg_employees[0], organization: org, leave_type: 'CP',
  start_date: w2, end_date: w2 + 2.days, days_count: 3,
  status: 'pending', reason: "Vacances famille"
)

# Backend dev (CDI) — en attente
LeaveRequest.create!(
  employee: be_employees[1], organization: org, leave_type: 'CP',
  start_date: w3, end_date: w3 + 4.days, days_count: 5,
  status: 'pending', reason: "Congés d'été"
)

# Sales SDR — en attente
LeaveRequest.create!(
  employee: sales_employees[2], organization: org, leave_type: 'CP',
  start_date: w2 + 3.days, end_date: w2 + 4.days, days_count: 2,
  status: 'pending', reason: "Week-end prolongé"
)

# ── Auto-approuvés (1 jour) ────────────────────────────────────────────────

LeaveRequest.create!(
  employee: fe_employees[2], organization: org, leave_type: 'CP',
  start_date: Date.tomorrow, end_date: Date.tomorrow, days_count: 1,
  status: 'auto_approved', reason: "Rendez-vous médical",
  approved_at: Time.current
)

LeaveRequest.create!(
  employee: devops_employees[2], organization: org, leave_type: 'CP',
  start_date: Date.tomorrow, end_date: Date.tomorrow, days_count: 1,
  status: 'auto_approved', reason: "Démarche administrative",
  approved_at: Time.current
)

# ── Arrêts maladie ────────────────────────────────────────────────────────

# Maladie en cours (cette semaine)
sick_today_start = today - 2.days
sick_today_start = today - 1.day if sick_today_start.saturday? || sick_today_start.sunday?
LeaveRequest.create!(
  employee: be_employees[2], organization: org, leave_type: 'Maladie',
  start_date: sick_today_start, end_date: today + 2.days,
  days_count: business_days_between(sick_today_start, today + 2.days),
  status: 'approved', reason: "Arrêt maladie (médecin)",
  approved_by: mgr_backend, approved_at: sick_today_start.to_time
)

# Maladie passée (il y a 3 semaines)
sick_past = today - 25.days
LeaveRequest.create!(
  employee: mktg_employees[1], organization: org, leave_type: 'Maladie',
  start_date: sick_past, end_date: sick_past + 2.days,
  days_count: 3,
  status: 'approved', reason: "Grippe",
  approved_by: mgr_mktg, approved_at: sick_past.to_time
)

# Maladie future prévue
LeaveRequest.create!(
  employee: product_employees[1], organization: org, leave_type: 'Maladie',
  start_date: w2, end_date: w2 + 4.days,
  days_count: 5,
  status: 'approved', reason: "Opération programmée",
  approved_by: mgr_product, approved_at: 3.days.ago
)

# ── Congés refusés ────────────────────────────────────────────────────────

LeaveRequest.create!(
  employee: sales_employees[3], organization: org, leave_type: 'CP',
  start_date: w1, end_date: w1 + 4.days, days_count: 5,
  status: 'rejected',
  reason: "Vacances été",
  rejection_reason: "Période de forte activité commerciale — merci de reporter après le 15 août",
  approved_by: mgr_sales, approved_at: 5.days.ago
)

# ── Congés annulés ────────────────────────────────────────────────────────

LeaveRequest.create!(
  employee: fe_employees[0], organization: org, leave_type: 'CP',
  start_date: w1 + 1.days, end_date: w1 + 2.days, days_count: 2,
  status: 'cancelled', reason: "Congé perso (annulé)"
)

# ── Passés approuvés (historique) ────────────────────────────────────────

LeaveRequest.create!(
  employee: be_employees[0], organization: org, leave_type: 'CP',
  start_date: 2.months.ago, end_date: 2.months.ago + 4.days,
  days_count: 5, status: 'approved',
  reason: "Vacances printemps",
  approved_by: mgr_backend, approved_at: 2.months.ago - 3.days
)

LeaveRequest.create!(
  employee: hr_generalist, organization: org, leave_type: 'CP',
  start_date: 6.weeks.ago, end_date: 6.weeks.ago + 4.days,
  days_count: 5, status: 'approved',
  reason: "Congés annuels",
  approved_by: dhr, approved_at: 7.weeks.ago
)

LeaveRequest.create!(
  employee: sales_employees[1], organization: org, leave_type: 'CP',
  start_date: 5.weeks.ago, end_date: 5.weeks.ago + 2.days,
  days_count: 3, status: 'approved',
  reason: "Long week-end",
  approved_by: mgr_sales, approved_at: 6.weeks.ago
)

puts "  Created #{LeaveRequest.count} leave requests"

# ─── Objectives ───────────────────────────────────────────────────────────────

puts "🎯 Creating objectives..."

# C-suite / strategic
obj_roadmap = Objective.create!(
  organization: org, manager: cto, created_by: cto,
  owner: cto, title: "Lancer la v2 de la plateforme",
  description: "Refonte complète du backend avec microservices. Inclut migration BDD et API v2.",
  status: 'in_progress', priority: 'critical',
  deadline: 3.months.from_now
)

obj_growth = Objective.create!(
  organization: org, manager: coo, created_by: coo,
  owner: coo, title: "Atteindre 200 clients actifs",
  description: "Objectif annuel de croissance — pipeline sales + marketing alignés.",
  status: 'in_progress', priority: 'high',
  deadline: 8.months.from_now
)

# Manager objectives
obj_perf_api = Objective.create!(
  organization: org, manager: cto, created_by: mgr_backend,
  owner: mgr_backend, title: "Réduire le temps de réponse API de 30%",
  description: "Profiling, cache Redis, optimisation queries N+1.",
  status: 'in_progress', priority: 'high',
  deadline: 6.weeks.from_now
)

obj_hiring = Objective.create!(
  organization: org, manager: dhr, created_by: dhr,
  owner: mgr_backend, title: "Recruter 2 développeurs backend seniors",
  description: "Besoin identifié Q1 — profils Golang/Ruby senior.",
  status: 'in_progress', priority: 'medium',
  deadline: 2.months.from_now
)

obj_design_system = Objective.create!(
  organization: org, manager: cto, created_by: mgr_frontend,
  owner: mgr_frontend, title: "Mettre en place un design system unifié",
  description: "Composants Storybook, tokens Tailwind, doc partagée avec Product.",
  status: 'draft', priority: 'medium',
  deadline: 4.months.from_now
)

# Employee-level objectives
obj_be_senior = Objective.create!(
  organization: org, manager: mgr_backend, created_by: mgr_backend,
  owner: be_employees[0], title: "Migrer le module de facturation vers l'API v2",
  description: "Responsable de la migration complète + tests de régression.",
  status: 'in_progress', priority: 'high',
  deadline: 5.weeks.from_now
)

obj_be_junior = Objective.create!(
  organization: org, manager: mgr_backend, created_by: mgr_backend,
  owner: be_employees[1], title: "Améliorer la couverture de tests à 80%",
  description: "Focus modules paiement et gestion des utilisateurs.",
  status: 'in_progress', priority: 'medium',
  deadline: 2.months.from_now
)

obj_fe_senior = Objective.create!(
  organization: org, manager: mgr_frontend, created_by: mgr_frontend,
  owner: fe_employees[0], title: "Réduire le bundle JS de 40%",
  description: "Code splitting, lazy loading, suppression dépendances inutilisées.",
  status: 'in_progress', priority: 'high',
  deadline: 3.weeks.from_now
)

obj_overdue = Objective.new(
  organization: org, manager: mgr_sales, created_by: mgr_sales,
  owner: sales_employees[2], title: "Atteindre 15 démos qualifiées ce mois",
  description: "Objectif mensuel SDR — suivi weekly avec Pierre.",
  status: 'in_progress', priority: 'high',
  deadline: 3.weeks.ago  # intentionally overdue
)
obj_overdue.save!(validate: false)

obj_completed = Objective.new(
  organization: org, manager: mgr_product, created_by: mgr_product,
  owner: product_employees[0], title: "Livrer les specs fonctionnelles du module RH",
  description: "Cahier des charges complet validé par la DHR.",
  status: 'completed', priority: 'high',
  deadline: 1.month.ago, completed_at: 5.weeks.ago
)
obj_completed.save!(validate: false)

obj_mktg = Objective.create!(
  organization: org, manager: mgr_mktg, created_by: mgr_mktg,
  owner: mktg_employees[0], title: "Publier 8 articles de blog ce trimestre",
  description: "SEO long-tail + thought leadership. Coordination avec Victor.",
  status: 'in_progress', priority: 'medium',
  deadline: 6.weeks.from_now
)

puts "  Created #{Objective.where(organization: org).count} objectives"

# ─── 1:1s ─────────────────────────────────────────────────────────────────────

puts "🤝 Creating 1:1 meetings..."

# Passés (completed)
[
  [mgr_backend,  be_employees[0], 3.weeks.ago,  "Bilan Q4 — bonne progression sur l'API. Blocker: accès prod à revoir.",    "Point avancement migration facturation. Suivi charge."],
  [mgr_backend,  be_employees[1], 2.weeks.ago,  "Tests: bon rythme. Formations Rspec à planifier.",                          "Couverture tests + montée en compétence."],
  [mgr_frontend, fe_employees[0], 3.weeks.ago,  "Bundle optimization bien avancé. Résultats Lighthouse prometteurs.",       "Optimisation perf frontend + retour équipe."],
  [mgr_sales,    sales_employees[0], 4.weeks.ago, "Pipeline Q1 solide. Relance 3 deals en stagnation.",                    "Revue pipeline + objectifs Q1."],
  [mgr_product,  product_employees[0], 3.weeks.ago, "Specs livrées. Prochaine étape: validation DHR.",                      "Livraison specs RH + planning sprint."],
  [cto,          mgr_backend, 2.weeks.ago,      "Recrutement 2 seniors validé. Budget approuvé COO.",                       "Staffing Engineering + roadmap v2."],
  [dhr,          hr_generalist, 5.weeks.ago,    "Bonne gestion des recrutements. Charge à surveiller.",                     "Bilan activité RH + charge de travail."],
].each do |mgr, emp, date, notes, agenda|
  OneOnOne.create!(
    organization: org, manager: mgr, employee: emp,
    scheduled_at: date, completed_at: date + 1.hour,
    status: 'completed', notes: notes, agenda: agenda
  )
end

# Planifiés (scheduled) — prochains jours
[
  [mgr_backend,  be_employees[0], 3.days.from_now,   "Suivi migration + blockers éventuels"],
  [mgr_backend,  be_employees[1], 4.days.from_now,   "Point tests + formation Rspec"],
  [mgr_backend,  be_employees[2], 5.days.from_now,   "Reprise après arrêt maladie — plan de charge"],
  [mgr_frontend, fe_employees[0], 2.days.from_now,   "Bilan bundle + retro sprint"],
  [mgr_frontend, fe_employees[1], 6.days.from_now,   "Point intégration + objectifs Q2"],
  [mgr_sales,    sales_employees[0], 4.days.from_now, "Pipeline Q2 + stratégie grands comptes"],
  [mgr_sales,    sales_employees[2], 3.days.from_now, "Objectifs SDR — rattrapage démos"],
  [mgr_product,  product_employees[1], 5.days.from_now, "Post arrêt — réintégration progressive"],
  [mgr_devops,   devops_employees[0], 2.days.from_now, "Incident post-mortem + plan action"],
  [mgr_mktg,     mktg_employees[0], 7.days.from_now,  "Bilan blog + planning Q2"],
  [cto,          mgr_frontend, 8.days.from_now,       "Design system — go/no-go Q2"],
  [dhr,          mgr_backend, 5.days.from_now,        "Recrutement backend — avancement sourcing"],
].each do |mgr, emp, date, agenda|
  OneOnOne.create!(
    organization: org, manager: mgr, employee: emp,
    scheduled_at: date, status: 'scheduled', agenda: agenda
  )
end

puts "  Created #{OneOnOne.where(organization: org).count} 1:1 meetings"

# ─── Trainings ────────────────────────────────────────────────────────────────

puts "📚 Creating trainings..."

t_ruby = Training.create!(
  organization: org, title: "Ruby on Rails — Avancé",
  description: "Patterns avancés : service objects, DDD, performance ActiveRecord, tests.",
  training_type: 'internal', duration_estimate: 16, provider: "TechCorp Academy"
)

t_k8s = Training.create!(
  organization: org, title: "Kubernetes & Helm en production",
  description: "Déploiement, scaling, monitoring avec Prometheus/Grafana.",
  training_type: 'certification', duration_estimate: 24, provider: "CNCF",
  external_url: "https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/"
)

t_security = Training.create!(
  organization: org, title: "Sécurité applicative — OWASP Top 10",
  description: "Audit de code, injections, XSS, CSRF, gestion des secrets.",
  training_type: 'e_learning', duration_estimate: 8, provider: "SANS Institute"
)

t_gdpr = Training.create!(
  organization: org, title: "RGPD & conformité données RH",
  description: "Obligations légales, droits des salariés, DPA, registre des traitements.",
  training_type: 'external', duration_estimate: 7, provider: "CNIL Formation"
)

t_leadership = Training.create!(
  organization: org, title: "Leadership & management d'équipe",
  description: "Feedback, gestion des conflits, motivation, conduite du changement.",
  training_type: 'mentoring', duration_estimate: 12, provider: "TechCorp Academy"
)

t_react = Training.create!(
  organization: org, title: "React 18 & Next.js — Maîtrise",
  description: "Server components, streaming, Suspense, optimistic UI.",
  training_type: 'e_learning', duration_estimate: 20, provider: "Frontend Masters"
)

t_agile = Training.create!(
  organization: org, title: "Product Management & Agile Avancé",
  description: "OKRs, Story mapping, priorisation RICE, roadmapping stratégique.",
  training_type: 'external', duration_estimate: 14, provider: "PM Institute"
)

# Training assignments
[
  # Backend team
  { emp: be_employees[0], t: t_ruby,     mgr: mgr_backend, status: 'in_progress', dl: 6.weeks.from_now,  started: 2.weeks.ago },
  { emp: be_employees[1], t: t_ruby,     mgr: mgr_backend, status: 'assigned',    dl: 8.weeks.from_now  },
  { emp: be_employees[2], t: t_security, mgr: mgr_backend, status: 'assigned',    dl: 10.weeks.from_now },
  { emp: be_employees[0], t: t_security, mgr: mgr_backend, status: 'completed',   dl: 1.month.ago,       completed: 5.weeks.ago,  notes: "Très bon niveau, a identifié 3 vulnérabilités sur le code legacy." },
  # DevOps
  { emp: devops_employees[0], t: t_k8s,      mgr: mgr_devops,  status: 'in_progress', dl: 4.weeks.from_now, started: 3.weeks.ago },
  { emp: devops_employees[1], t: t_k8s,      mgr: mgr_devops,  status: 'assigned',    dl: 6.weeks.from_now },
  { emp: devops_employees[2], t: t_security, mgr: mgr_devops,  status: 'assigned',    dl: 8.weeks.from_now },
  # Frontend
  { emp: fe_employees[0], t: t_react,    mgr: mgr_frontend, status: 'completed',  dl: 2.months.ago, completed: 7.weeks.ago, notes: "Excellente maîtrise. Déjà appliqué sur le dashboard." },
  { emp: fe_employees[1], t: t_react,    mgr: mgr_frontend, status: 'in_progress', dl: 5.weeks.from_now, started: 1.week.ago },
  { emp: fe_employees[2], t: t_react,    mgr: mgr_frontend, status: 'assigned',    dl: 9.weeks.from_now },
  # HR team
  { emp: hr_generalist,   t: t_gdpr,     mgr: dhr,          status: 'completed',  dl: 1.month.ago, completed: 5.weeks.ago, notes: "Validé — registre mis à jour." },
  { emp: hr_recruiter,    t: t_gdpr,     mgr: dhr,          status: 'in_progress', dl: 3.weeks.from_now, started: 1.week.ago },
  # Managers — leadership
  { emp: mgr_backend,    t: t_leadership, mgr: cto,  status: 'in_progress', dl: 8.weeks.from_now, started: 2.weeks.ago },
  { emp: mgr_sales,      t: t_leadership, mgr: coo,  status: 'assigned',    dl: 10.weeks.from_now },
  # Product
  { emp: product_employees[0], t: t_agile, mgr: mgr_product, status: 'completed', dl: 6.weeks.ago, completed: 7.weeks.ago, notes: "Certification obtenue. Roadmap Q2 déjà restructurée." },
  { emp: product_employees[1], t: t_agile, mgr: mgr_product, status: 'assigned',  dl: 6.weeks.from_now },
].each do |a|
  ta = TrainingAssignment.create!(
    training: a[:t], employee: a[:emp], assigned_by: a[:mgr],
    status: a[:status], assigned_at: 1.month.ago,
    deadline: a[:dl],
    completed_at: a[:completed],
    completion_notes: a[:notes]
  )
  # Simulate in_progress start date via metadata (no started_at column)
end

puts "  Created #{Training.where(organization: org).count} trainings, #{TrainingAssignment.count} assignments"

# ─── Onboarding Templates + 3 Onboardings ─────────────────────────────────────

puts "🚀 Creating onboarding templates & onboardings..."

# Template Engineering
tpl_eng = OnboardingTemplate.create!(
  organization: org, name: "Onboarding Engineering",
  description: "Parcours d'intégration pour les développeurs et DevOps.",
  duration_days: 90, active: true
)

[
  { title: "Accès GitHub, Jira, Confluence",      role: 'hr',      type: 'manual',     day: 1  },
  { title: "Setup poste de travail",               role: 'hr',      type: 'manual',     day: 1  },
  { title: "Présentation de l'équipe",             role: 'manager', type: 'one_on_one', day: 2  },
  { title: "Lecture architecture technique",       role: 'employee', type: 'training',  day: 3  },
  { title: "Premier ticket Jira en binôme",        role: 'manager', type: 'manual',     day: 5  },
  { title: "Formation sécurité applicative",       role: 'employee', type: 'training',  day: 10 },
  { title: "Code review avec senior",              role: 'manager', type: 'one_on_one', day: 14 },
  { title: "Premier déploiement en staging",       role: 'employee', type: 'manual',    day: 21 },
  { title: "Bilan J30 avec manager",               role: 'manager', type: 'one_on_one', day: 30 },
  { title: "Accès production validé",              role: 'manager', type: 'manual',     day: 45 },
  { title: "Bilan J60 — objectifs fixés",          role: 'manager', type: 'objective_60', day: 60 },
  { title: "Évaluation fin de période d'essai",    role: 'manager', type: 'one_on_one', day: 90 },
].each_with_index do |t, i|
  OnboardingTemplateTask.create!(
    onboarding_template: tpl_eng, organization: org,
    title: t[:title], assigned_to_role: t[:role], task_type: t[:type],
    due_day_offset: t[:day], position: i + 1
  )
end

# Template Sales
tpl_sales = OnboardingTemplate.create!(
  organization: org, name: "Onboarding Sales",
  description: "Intégration commerciaux : produit, process, outils CRM.",
  duration_days: 60, active: true
)

[
  { title: "Accès CRM Salesforce + outils",        role: 'hr',       type: 'manual',       day: 1  },
  { title: "Formation produit — démo complète",    role: 'manager',  type: 'training',     day: 2  },
  { title: "Shadow call avec senior",              role: 'manager',  type: 'one_on_one',   day: 3  },
  { title: "Première démo autonome",               role: 'employee', type: 'manual',       day: 7  },
  { title: "Maîtrise process de qualification",    role: 'manager',  type: 'training',     day: 10 },
  { title: "Premier deal ouvert dans CRM",         role: 'employee', type: 'manual',       day: 14 },
  { title: "Bilan J30 — pipeline review",          role: 'manager',  type: 'one_on_one',   day: 30 },
  { title: "Objectifs Q1 fixés avec manager",      role: 'manager',  type: 'objective_30', day: 45 },
  { title: "Évaluation fin de période d'essai",    role: 'manager',  type: 'one_on_one',   day: 60 },
].each_with_index do |t, i|
  OnboardingTemplateTask.create!(
    onboarding_template: tpl_sales, organization: org,
    title: t[:title], assigned_to_role: t[:role], task_type: t[:type],
    due_day_offset: t[:day], position: i + 1
  )
end

# ── Onboarding 1 : Tout juste commencé (J+3) ──────────────────────────────────
# Ana Ferreira, stagiaire backend — démarre il y a 3 jours

ob1_start = 3.days.ago.to_date
ob1 = EmployeeOnboarding.create!(
  organization: org,
  employee: be_employees[4],   # Ana Ferreira
  manager: mgr_backend,
  onboarding_template: tpl_eng,
  start_date: ob1_start,
  end_date: ob1_start + 90.days,
  status: 'active',
  notes: "Stagiaire backend — intégration 3 mois. Binôme avec Julien."
)

# Tâches : les 2 premières complétées (J1), les suivantes pending
OnboardingTask.create!(employee_onboarding: ob1, organization: org, title: "Accès GitHub, Jira, Confluence",
  assigned_to_role: 'hr', task_type: 'manual', due_date: ob1_start + 1.day,
  status: 'completed', completed_at: ob1_start + 1.day, completed_by: hr_generalist, assigned_to: hr_generalist)
OnboardingTask.create!(employee_onboarding: ob1, organization: org, title: "Setup poste de travail",
  assigned_to_role: 'hr', task_type: 'manual', due_date: ob1_start + 1.day,
  status: 'completed', completed_at: ob1_start + 1.day, completed_by: hr_generalist, assigned_to: hr_generalist)
OnboardingTask.create!(employee_onboarding: ob1, organization: org, title: "Présentation de l'équipe",
  assigned_to_role: 'manager', task_type: 'one_on_one', due_date: ob1_start + 2.days,
  status: 'completed', completed_at: ob1_start + 2.days, completed_by: mgr_backend, assigned_to: mgr_backend)
OnboardingTask.create!(employee_onboarding: ob1, organization: org, title: "Lecture architecture technique",
  assigned_to_role: 'employee', task_type: 'training', due_date: ob1_start + 3.days,
  status: 'pending', assigned_to: be_employees[4])
OnboardingTask.create!(employee_onboarding: ob1, organization: org, title: "Premier ticket Jira en binôme",
  assigned_to_role: 'manager', task_type: 'manual', due_date: ob1_start + 5.days,
  status: 'pending', assigned_to: mgr_backend)
OnboardingTask.create!(employee_onboarding: ob1, organization: org, title: "Formation sécurité applicative",
  assigned_to_role: 'employee', task_type: 'training', due_date: ob1_start + 10.days,
  status: 'pending', assigned_to: be_employees[4])

# Rafraîchir le cache
EmployeeOnboardingScoreRefreshJob.perform_now(ob1.id)

# ── Onboarding 2 : À mi-parcours (~J45 sur 90) ────────────────────────────────
# Yanis Benali, alternant frontend — commencé il y a 45 jours

ob2_start = 45.days.ago.to_date
ob2 = EmployeeOnboarding.create!(
  organization: org,
  employee: fe_employees[3],   # Yanis Benali
  manager: mgr_frontend,
  onboarding_template: tpl_eng,
  start_date: ob2_start,
  end_date: ob2_start + 90.days,
  status: 'active',
  notes: "Alternant frontend — rythme 3j entreprise / 2j école."
)

tasks_ob2 = [
  { title: "Accès GitHub, Jira, Confluence",    role: 'hr',      type: 'manual', offset: 1,  done: true,  by: hr_generalist },
  { title: "Setup poste de travail",             role: 'hr',      type: 'manual', offset: 1,  done: true,  by: hr_generalist },
  { title: "Présentation de l'équipe",           role: 'manager', type: 'one_on_one',        offset: 2,  done: true,  by: mgr_frontend },
  { title: "Lecture architecture technique",     role: 'employee', type: 'training',      offset: 3,  done: true,  by: fe_employees[3] },
  { title: "Premier ticket Jira en binôme",      role: 'manager', type: 'manual',           offset: 5,  done: true,  by: mgr_frontend },
  { title: "Formation sécurité applicative",     role: 'employee', type: 'training',      offset: 10, done: true,  by: fe_employees[3] },
  { title: "Code review avec senior",            role: 'manager', type: 'one_on_one',        offset: 14, done: true,  by: mgr_frontend },
  { title: "Premier déploiement en staging",     role: 'employee', type: 'manual',          offset: 21, done: true,  by: fe_employees[3] },
  { title: "Bilan J30 avec manager",             role: 'manager', type: 'one_on_one',        offset: 30, done: true,  by: mgr_frontend },
  { title: "Accès production validé",            role: 'manager', type: 'manual', offset: 45, done: false },
  { title: "Bilan J60 — objectifs fixés",        role: 'manager', type: 'one_on_one',        offset: 60, done: false },
  { title: "Évaluation fin de période d'essai",  role: 'manager', type: 'one_on_one',        offset: 90, done: false },
]

tasks_ob2.each do |t|
  due = ob2_start + t[:offset].days
  if t[:done]
    OnboardingTask.create!(employee_onboarding: ob2, organization: org, title: t[:title],
      assigned_to_role: t[:role], task_type: t[:type], due_date: due,
      status: 'completed', completed_at: due, completed_by: t[:by], assigned_to: t[:by])
  else
    assignee = t[:role] == 'manager' ? mgr_frontend : fe_employees[3]
    OnboardingTask.create!(employee_onboarding: ob2, organization: org, title: t[:title],
      assigned_to_role: t[:role], task_type: t[:type], due_date: due,
      status: 'pending', assigned_to: assignee)
  end
end

EmployeeOnboardingScoreRefreshJob.perform_now(ob2.id)

# ── Onboarding 3 : Presque terminé (~J80 sur 90) ──────────────────────────────
# Sarah Cohen, Business Developer Sales — commencée il y a 50 jours sur template 60j

ob3_start = 50.days.ago.to_date
ob3 = EmployeeOnboarding.create!(
  organization: org,
  employee: sales_employees[4],  # Sarah Cohen
  manager: mgr_sales,
  onboarding_template: tpl_sales,
  start_date: ob3_start,
  end_date: ob3_start + 60.days,
  status: 'active',
  notes: "Profil expérimenté — intégration accélérée sur la partie produit."
)

tasks_ob3 = [
  { title: "Accès CRM Salesforce + outils",       role: 'hr',      type: 'manual', offset: 1,  done: true,  by: hr_generalist },
  { title: "Formation produit — démo complète",   role: 'manager', type: 'training',       offset: 2,  done: true,  by: mgr_sales },
  { title: "Shadow call avec senior",             role: 'manager', type: 'one_on_one',        offset: 3,  done: true,  by: mgr_sales },
  { title: "Première démo autonome",              role: 'employee', type: 'manual',          offset: 7,  done: true,  by: sales_employees[4] },
  { title: "Maîtrise process de qualification",   role: 'manager', type: 'training',       offset: 10, done: true,  by: mgr_sales },
  { title: "Premier deal ouvert dans CRM",        role: 'employee', type: 'manual',          offset: 14, done: true,  by: sales_employees[4] },
  { title: "Bilan J30 — pipeline review",         role: 'manager', type: 'one_on_one',        offset: 30, done: true,  by: mgr_sales },
  { title: "Objectifs Q1 fixés avec manager",     role: 'manager', type: 'one_on_one',        offset: 45, done: true,  by: mgr_sales },
  { title: "Évaluation fin de période d'essai",   role: 'manager', type: 'one_on_one',        offset: 60, done: false },
]

tasks_ob3.each do |t|
  due = ob3_start + t[:offset].days
  if t[:done]
    OnboardingTask.create!(employee_onboarding: ob3, organization: org, title: t[:title],
      assigned_to_role: t[:role], task_type: t[:type], due_date: due,
      status: 'completed', completed_at: due, completed_by: t[:by], assigned_to: t[:by])
  else
    OnboardingTask.create!(employee_onboarding: ob3, organization: org, title: t[:title],
      assigned_to_role: t[:role], task_type: t[:type], due_date: due,
      status: 'pending', assigned_to: mgr_sales)
  end
end

EmployeeOnboardingScoreRefreshJob.perform_now(ob3.id)

puts "  Created #{EmployeeOnboarding.where(organization: org).count} onboardings, #{OnboardingTask.where(organization: org).count} tasks"

# ─── Organisation 2 — Studio Créatif (Manager OS) ────────────────────────────

puts "\n🏢 Creating second organization: Studio Créatif (Manager OS)..."
org2 = Organization.create!(
  name: "Studio Créatif",
  plan: "manager_os",
  settings: { work_week_hours: 39, cp_acquisition_rate: 2.5, rtt_enabled: true, overtime_threshold: 35 }
)

# ── Équipe direction ──────────────────────────────────────────────────────────

admin2 = org2.employees.create!(
  email: "admin@studio-creatif.fr", password: "password123",
  first_name: "Sophie", last_name: "Laurent",
  role: "admin", department: "Direction", job_title: "CEO & Fondatrice",
  contract_type: "CDI", start_date: 4.years.ago,
  gross_salary_cents: 920000, variable_pay_cents: 180000, employer_charges_rate: 1.45,
  settings: { "cadre" => true, "active" => true }
)

mgr_studio = org2.employees.create!(
  email: "lucas.martin@studio-creatif.fr", password: "password123",
  first_name: "Lucas", last_name: "Martin",
  role: "manager", department: "Design & Tech", job_title: "Head of Design",
  contract_type: "CDI", start_date: 2.years.ago, manager: admin2,
  gross_salary_cents: 620000, variable_pay_cents: 80000, employer_charges_rate: 1.45,
  settings: { "cadre" => true, "active" => true }
)

# ── Membres d'équipe ──────────────────────────────────────────────────────────

team_data = [
  ["camille.dupont@studio-creatif.fr",  "Camille", "Dupont",   "UX Designer Senior",     14.months.ago, 480000, "CDI"],
  ["thomas.garcia@studio-creatif.fr",   "Thomas",  "Garcia",   "Développeur Front-end",  10.months.ago, 520000, "CDI"],
  ["inès.benali@studio-creatif.fr",     "Inès",    "Benali",   "Motion Designer",         7.months.ago, 420000, "CDI"],
  ["romain.leclerc@studio-creatif.fr",  "Romain",  "Leclerc",  "Product Designer",        5.months.ago, 460000, "CDI"],
  ["amandine.rey@studio-creatif.fr",    "Amandine","Rey",       "UI Designer",             2.months.ago, 390000, "CDI"],
  ["kevin.moreau@studio-creatif.fr",    "Kévin",   "Moreau",   "Développeur Full-stack",  3.weeks.ago,  440000, "CDI"],
]

s2_members = team_data.map do |email, fn, ln, jt, sd, sal, ct|
  emp = org2.employees.create!(
    email: email, password: "password123",
    first_name: fn, last_name: ln, role: "employee",
    department: "Design & Tech", job_title: jt,
    contract_type: ct, start_date: sd, manager: mgr_studio,
    gross_salary_cents: sal, variable_pay_cents: 0, employer_charges_rate: 1.45,
    settings: { "cadre" => false, "active" => true }
  )
  WorkSchedule.create_from_template(emp, 'full_time_39h')
  months = ((Date.current - sd.to_date) / 30).to_i
  LeaveBalance.create!(employee: emp, organization: org2, leave_type: 'CP',
    balance: [months * 2.5, 30].min, accrued_this_year: [months * 2.5, 30].min,
    used_this_year: 0, expires_at: Date.new(Date.current.year + 1, 5, 31))
  LeaveBalance.create!(employee: emp, organization: org2, leave_type: 'Maladie',
    balance: 0, accrued_this_year: 0, used_this_year: 0)
  emp
end

camille, thomas, ines, romain, amandine, kevin = s2_members

# ── Objectifs ────────────────────────────────────────────────────────────────

puts "  Creating objectives..."

Objective.create!(organization: org2, manager: admin2, created_by: admin2,
  owner: mgr_studio,
  title: "Lancer le nouveau site vitrine d'ici fin Q2",
  description: "Refonte complète — nouveau branding, performances Core Web Vitals > 90. Livraison en juin.",
  status: 'in_progress', priority: 'critical', deadline: 7.weeks.from_now)

Objective.create!(organization: org2, manager: mgr_studio, created_by: mgr_studio,
  owner: camille,
  title: "Conduire 8 tests utilisateurs sur le nouveau parcours d'achat",
  description: "Recrutement panel, guide d'entretien, synthèse insights. Résultats présentés en rétrospective sprint.",
  status: 'in_progress', priority: 'high', deadline: 3.weeks.from_now)

Objective.create!(organization: org2, manager: mgr_studio, created_by: mgr_studio,
  owner: thomas,
  title: "Migrer le front-end vers React 18 + TypeScript strict",
  description: "Zero erreurs TS, couverture de tests > 70%, pipeline CI vert.",
  status: 'in_progress', priority: 'high', deadline: 5.weeks.from_now)

obj_ines = Objective.create!(organization: org2, manager: mgr_studio, created_by: mgr_studio,
  owner: ines,
  title: "Créer la bibliothèque de 30 animations pour le design system",
  description: "Lottie + CSS animations. Documentées dans Storybook. Validées par Lucas.",
  status: 'completed', priority: 'medium', deadline: 1.week.from_now)
obj_ines.update_column(:deadline, 3.weeks.ago)

Objective.create!(organization: org2, manager: mgr_studio, created_by: mgr_studio,
  owner: romain,
  title: "Définir les guidelines du nouveau design system",
  description: "Tokens couleur, typographie, spacing. Figma + documentation Notion.",
  status: 'in_progress', priority: 'high', deadline: 2.weeks.from_now)

obj_camille_a11y = Objective.create!(organization: org2, manager: mgr_studio, created_by: mgr_studio,
  owner: camille,
  title: "Auditer l'accessibilité WCAG 2.1 AA du produit actuel",
  description: "Rapport complet, priorisation des 10 critères bloquants, plan de correction.",
  status: 'completed', priority: 'medium', deadline: 1.week.from_now)
obj_camille_a11y.update_column(:deadline, 6.weeks.ago)

Objective.create!(organization: org2, manager: mgr_studio, created_by: mgr_studio,
  owner: thomas,
  title: "Réduire le temps de build de 40%",
  description: "Analyse profiling webpack, optimisation imports, passage à Vite si pertinent.",
  status: 'draft', priority: 'low', deadline: 10.weeks.from_now)

Objective.create!(organization: org2, manager: mgr_studio, created_by: mgr_studio,
  owner: romain,
  title: "Onboarder Amandine sur le design system",
  description: "Sessions de travail en pair, checklist autonomie validée en J+30.",
  status: 'in_progress', priority: 'medium', deadline: 3.weeks.from_now)

# ── Tâches d'objectifs ────────────────────────────────────────────────────────

puts "  Creating objective tasks..."

ActsAsTenant.with_tenant(org2) do
  obj_tests = Objective.find_by(title: "Conduire 8 tests utilisateurs sur le nouveau parcours d'achat")
  obj_react  = Objective.find_by(title: "Migrer le front-end vers React 18 + TypeScript strict")
  obj_design = Objective.find_by(title: "Définir les guidelines du nouveau design system")

  if obj_tests
    [
      { title: "Recruter 8 participants test",          desc: "Panel diversifié — 4 clients existants, 4 prospects.", deadline: 3.weeks.from_now, status: 'validated', pos: 1 },
      { title: "Rédiger le guide d'entretien",          desc: "Questions ouvertes, scénarios, grille d'observation.", deadline: 2.weeks.from_now, status: 'validated', pos: 2 },
      { title: "Conduire les 8 sessions (5/8 faites)",  desc: "Sessions en remote via Maze. 45 min chacune.",         deadline: 1.week.from_now,  status: 'done',      pos: 3 },
      { title: "Synthèse insights + recommandations",   desc: "Top 5 frictions identifiées, plan de correction.",    deadline: 3.weeks.from_now, status: 'todo',      pos: 4 },
    ].each do |t|
      task = ObjectiveTask.create!(
        organization: org2, objective: obj_tests,
        title: t[:title], description: t[:desc],
        deadline: t[:deadline], assigned_to: camille,
        status: t[:status], position: t[:pos]
      )
      if t[:status] == 'validated'
        task.update_columns(completed_at: 1.week.ago, completed_by_id: camille.id, validated_at: 3.days.ago, validated_by_id: mgr_studio.id)
      elsif t[:status] == 'done'
        task.update_columns(completed_at: 2.days.ago, completed_by_id: camille.id)
      end
    end
  end

  if obj_react
    [
      { title: "Activer strict mode TypeScript",           desc: "tsconfig.json — noImplicitAny, strictNullChecks.", deadline: 4.weeks.from_now, status: 'validated', pos: 1 },
      { title: "Migrer les composants core (50 fichiers)", desc: "Priorité : Auth, Layout, DataTable.",              deadline: 3.weeks.from_now, status: 'done',      pos: 2 },
      { title: "Migrer les pages (30 fichiers)",           desc: "Après les composants core.",                       deadline: 2.weeks.from_now, status: 'todo',      pos: 3 },
      { title: "Pipeline CI — zero erreurs TS",            desc: "GitHub Actions — block merge si TS errors.",       deadline: 1.week.from_now,  status: 'todo',      pos: 4 },
      { title: "Coverage tests > 70%",                    desc: "Jest + React Testing Library.",                    deadline: 5.weeks.from_now, status: 'todo',      pos: 5 },
    ].each do |t|
      task = ObjectiveTask.create!(
        organization: org2, objective: obj_react,
        title: t[:title], description: t[:desc],
        deadline: t[:deadline], assigned_to: thomas,
        status: t[:status], position: t[:pos]
      )
      if t[:status] == 'validated'
        task.update_columns(completed_at: 2.weeks.ago, completed_by_id: thomas.id, validated_at: 1.week.ago, validated_by_id: mgr_studio.id)
      elsif t[:status] == 'done'
        task.update_columns(completed_at: 3.days.ago, completed_by_id: thomas.id)
      end
    end
  end

  if obj_design
    [
      { title: "Définir les tokens couleur (light + dark)", desc: "Primary, secondary, neutrals, semantic.",  deadline: 1.week.from_now,  status: 'validated', pos: 1 },
      { title: "Définir les tokens typographie",            desc: "Scale, line-height, font-weight.",         deadline: 1.week.from_now,  status: 'validated', pos: 2 },
      { title: "Définir les tokens spacing",                desc: "Base 4px grid, rem values.",              deadline: 2.weeks.from_now, status: 'done',      pos: 3 },
      { title: "Documentation Notion + Figma",              desc: "Page Notion liée aux frames Figma.",       deadline: 2.weeks.from_now, status: 'todo',      pos: 4 },
    ].each do |t|
      task = ObjectiveTask.create!(
        organization: org2, objective: obj_design,
        title: t[:title], description: t[:desc],
        deadline: t[:deadline], assigned_to: romain,
        status: t[:status], position: t[:pos]
      )
      if t[:status] == 'validated'
        task.update_columns(completed_at: 1.week.ago, completed_by_id: romain.id, validated_at: 4.days.ago, validated_by_id: mgr_studio.id)
      elsif t[:status] == 'done'
        task.update_columns(completed_at: 1.day.ago, completed_by_id: romain.id)
      end
    end
  end
end

# ── Entretiens 1:1 ───────────────────────────────────────────────────────────

puts "  Creating 1:1 meetings..."

# Passés
[
  [camille, 3.weeks.ago, "Point Q1 — résultats tests utilisateurs + objectifs Q2",
   "Très bonne dynamique sur les tests. Camille prend de l'autonomie. Proposé lead sur le parcours mobile en Q2."],
  [thomas,  3.weeks.ago, "Bilan technique — migration React 18",
   "Blocage sur les types génériques. Prévu session pair-programming avec Kevin la semaine prochaine."],
  [ines,    2.weeks.ago, "Revue animations bibliothèque — livraison prévue",
   "Librairie quasi terminée. 2 animations manquantes. Délai tenu. Excellent travail."],
  [romain,  2.weeks.ago, "Kick-off design system + intégration Amandine",
   "Romain est partant pour le rôle de mentor. Plan de 30 jours établi ensemble."],
  [camille, 1.week.ago,  "Suivi tests utilisateurs — itération 2",
   "5 tests réalisés sur 8. Insights clés : confusion sur le checkout. Plan de correction partagé."],
  [thomas,  1.week.ago,  "Session technique — TypeScript strict mode",
   "Avancement bon. 80% des fichiers migrés. Blocage sur les types d'API — besoin doc OpenAPI."],
].each do |emp, sched, agenda, notes|
  OneOnOne.create!(organization: org2, manager: mgr_studio,
    employee: emp, scheduled_at: sched,
    completed_at: sched + 1.hour, status: 'completed',
    agenda: agenda, notes: notes)
end

# À venir cette semaine / semaine prochaine
[
  [camille,  2.days.from_now,  "Retour tests utilisateurs — itération 3 + priorisation correctifs"],
  [thomas,   3.days.from_now,  "Finalisation migration TS + revue CI pipeline"],
  [ines,     4.days.from_now,  "Bilan Q2 animations + nouveaux objectifs"],
  [romain,   5.days.from_now,  "Design system — review tokens avec l'équipe"],
  [amandine, 6.days.from_now,  "Premier 1:1 — intégration J+30 + objectifs"],
  [kevin,    8.days.from_now,  "Onboarding kick-off — accès, stack, premiers tickets"],
].each do |emp, sched, agenda|
  OneOnOne.create!(organization: org2, manager: mgr_studio,
    employee: emp, scheduled_at: sched,
    status: 'scheduled', agenda: agenda)
end

# ── Formations ───────────────────────────────────────────────────────────────

puts "  Creating trainings..."

t_figma = Training.create!(organization: org2,
  title: "Figma Advanced — Variables & Auto-Layout",
  description: "Maîtriser les variables Figma, auto-layout avancé et composants dynamiques.",
  training_type: 'e_learning', duration_estimate: 6)

t_a11y = Training.create!(organization: org2,
  title: "Accessibilité web — WCAG 2.1 pratique",
  description: "Comprendre et appliquer les critères WCAG 2.1 AA. Outils d'audit, patterns ARIA.",
  training_type: 'external', duration_estimate: 14)

t_react = Training.create!(organization: org2,
  title: "React 18 — Concurrent features & TypeScript",
  description: "useTransition, Suspense, Server Components. Migration patterns et bonnes pratiques TS.",
  training_type: 'e_learning', duration_estimate: 8)

t_leadership = Training.create!(organization: org2,
  title: "Leadership & feedback manager",
  description: "Donner du feedback constructif, conduire des 1:1 efficaces, gérer les tensions d'équipe.",
  training_type: 'external', duration_estimate: 7)

t_motion = Training.create!(organization: org2,
  title: "Motion Design — After Effects & Lottie",
  description: "Créer des animations UI exportables en Lottie. Intégration dans React et iOS.",
  training_type: 'e_learning', duration_estimate: 10)

# Assignations
TrainingAssignment.create!(training: t_figma, employee: amandine,
  assigned_by: mgr_studio, assigned_at: 3.weeks.ago,
  status: 'in_progress')

TrainingAssignment.create!(training: t_figma, employee: romain,
  assigned_by: mgr_studio, assigned_at: 3.weeks.ago,
  status: 'completed', completed_at: 1.week.ago)

TrainingAssignment.create!(training: t_a11y, employee: camille,
  assigned_by: mgr_studio, assigned_at: 2.months.ago,
  status: 'completed', completed_at: 5.weeks.ago)

TrainingAssignment.create!(training: t_a11y, employee: thomas,
  assigned_by: mgr_studio, assigned_at: 3.weeks.ago,
  status: 'assigned')

TrainingAssignment.create!(training: t_react, employee: thomas,
  assigned_by: mgr_studio, assigned_at: 6.weeks.ago,
  status: 'in_progress')

TrainingAssignment.create!(training: t_react, employee: kevin,
  assigned_by: mgr_studio, assigned_at: 1.week.ago,
  status: 'assigned')

TrainingAssignment.create!(training: t_leadership, employee: mgr_studio,
  assigned_by: admin2, assigned_at: 1.month.ago,
  status: 'in_progress')

TrainingAssignment.create!(training: t_motion, employee: ines,
  assigned_by: mgr_studio, assigned_at: 2.months.ago,
  status: 'completed', completed_at: 3.weeks.ago)

# ── Évaluations ──────────────────────────────────────────────────────────────

puts "  Creating evaluations..."

Evaluation.create!(organization: org2,
  employee: camille, manager: mgr_studio, created_by: mgr_studio,
  period_start: 6.months.ago, period_end: 1.month.ago,
  status: 'completed',
  score: 4,
  manager_review: "Camille a pris une vraie posture de leadership sur les tests utilisateurs. Livrables de qualité, bonne communication avec les devs. Prête pour plus de responsabilités en Q3.",
  self_review: "Période enrichissante. J'aimerais m'impliquer davantage sur la stratégie produit et pas seulement l'exécution UX.")

Evaluation.create!(organization: org2,
  employee: thomas, manager: mgr_studio, created_by: mgr_studio,
  period_start: 6.months.ago, period_end: 1.month.ago,
  status: 'manager_review_pending',
  self_review: "Migration complexe mais je progresse. Besoin d'un peu plus de visibilité sur la roadmap technique pour mieux prioriser.")

Evaluation.create!(organization: org2,
  employee: ines, manager: mgr_studio, created_by: mgr_studio,
  period_start: 3.months.ago, period_end: Date.current,
  status: 'employee_review_pending',
  manager_review: "Bibliothèque d'animations livrée dans les temps, qualité excellente. Inès est une référence motion pour toute l'équipe.")

Evaluation.create!(organization: org2,
  employee: romain, manager: mgr_studio, created_by: mgr_studio,
  period_start: 4.months.ago, period_end: 1.week.ago,
  status: 'completed',
  score: 3,
  manager_review: "Bon travail sur le design system. La documentation peut encore être améliorée. Montée en compétence visible sur Figma Variables.",
  self_review: "Contenu de la direction prise sur le design system. L'objectif mentor avec Amandine me motive beaucoup.")

# ── Onboarding template ───────────────────────────────────────────────────────

puts "  Creating onboarding template..."

tpl_studio = OnboardingTemplate.create!(
  organization: org2,
  name: "Onboarding Studio — 45 jours",
  description: "Intégration créative en 45 jours — culture, outils, premier projet en autonomie.",
  duration_days: 45, active: true
)

[
  { title: "Accès outils (Figma, Slack, Notion, GitHub)",  role: 'hr',       type: 'manual',     day: 1  },
  { title: "Tour des bureaux + rencontre équipe",          role: 'manager',  type: 'one_on_one', day: 1  },
  { title: "Session culture & valeurs avec la CEO",        role: 'manager',  type: 'one_on_one', day: 2  },
  { title: "Lecture du Playbook Design Studio",            role: 'employee', type: 'training',   day: 3  },
  { title: "Formation Figma Advanced assignée",            role: 'manager',  type: 'training',   day: 5  },
  { title: "Premier brief créatif en binôme",             role: 'employee', type: 'manual',     day: 7  },
  { title: "Bilan J14 — intégration & ressenti",          role: 'manager',  type: 'one_on_one', day: 14 },
  { title: "Première présentation client (observateur)",  role: 'employee', type: 'manual',     day: 21 },
  { title: "Revue qualité premier livrable solo",         role: 'manager',  type: 'one_on_one', day: 30 },
  { title: "Bilan fin période d'essai",                   role: 'manager',  type: 'one_on_one', day: 45 },
].each_with_index do |t, i|
  OnboardingTemplateTask.create!(
    onboarding_template: tpl_studio, organization: org2,
    title: t[:title], assigned_to_role: t[:role], task_type: t[:type],
    due_day_offset: t[:day], position: i + 1
  )
end

# ── Onboardings actifs ────────────────────────────────────────────────────────

puts "  Creating onboardings..."

# Amandine — arrivée il y a 2 mois, onboarding terminé
ob_amandine = EmployeeOnboarding.create!(
  organization: org2, employee: amandine, manager: mgr_studio,
  onboarding_template: tpl_studio,
  start_date: amandine.start_date, end_date: amandine.start_date + 45.days,
  status: 'completed', notes: "UI Designer — intégration réussie, très bonne adaptation."
)

[
  ["Accès outils (Figma, Slack, Notion, GitHub)", 'hr',       'manual',     1,  admin2,      amandine.start_date + 1.day],
  ["Tour des bureaux + rencontre équipe",         'manager',  'one_on_one', 1,  mgr_studio,  amandine.start_date + 1.day],
  ["Session culture & valeurs avec la CEO",       'manager',  'one_on_one', 2,  admin2,      amandine.start_date + 2.days],
  ["Lecture du Playbook Design Studio",           'employee', 'training',   3,  amandine,    amandine.start_date + 3.days],
  ["Formation Figma Advanced assignée",           'manager',  'training',   5,  mgr_studio,  amandine.start_date + 5.days],
  ["Premier brief créatif en binôme",            'employee', 'manual',     7,  amandine,    amandine.start_date + 7.days],
  ["Bilan J14 — intégration & ressenti",         'manager',  'one_on_one', 14, mgr_studio,  amandine.start_date + 14.days],
  ["Première présentation client (observateur)", 'employee', 'manual',     21, amandine,    amandine.start_date + 21.days],
  ["Revue qualité premier livrable solo",        'manager',  'one_on_one', 30, mgr_studio,  amandine.start_date + 30.days],
  ["Bilan fin période d'essai",                  'manager',  'one_on_one', 45, mgr_studio,  amandine.start_date + 45.days],
].each do |title, role, type, day, assignee, completed|
  OnboardingTask.create!(employee_onboarding: ob_amandine, organization: org2,
    title: title, assigned_to_role: role, task_type: type,
    due_date: amandine.start_date + day.days,
    status: 'completed', completed_at: completed,
    completed_by: assignee, assigned_to: assignee)
end

EmployeeOnboardingScoreRefreshJob.perform_now(ob_amandine.id)

# Kévin — arrivé il y a 3 semaines, onboarding en cours
ob_kevin = EmployeeOnboarding.create!(
  organization: org2, employee: kevin, manager: mgr_studio,
  onboarding_template: tpl_studio,
  start_date: kevin.start_date, end_date: kevin.start_date + 45.days,
  status: 'active', notes: "Développeur Full-stack — prise de poste rapide, déjà opérationnel sur les tickets."
)

kevin_tasks = [
  ["Accès outils (Figma, Slack, Notion, GitHub)", 'hr',       'manual',     1,  admin2,     :completed, kevin.start_date + 1.day],
  ["Tour des bureaux + rencontre équipe",         'manager',  'one_on_one', 1,  mgr_studio, :completed, kevin.start_date + 1.day],
  ["Session culture & valeurs avec la CEO",       'manager',  'one_on_one', 2,  admin2,     :completed, kevin.start_date + 2.days],
  ["Lecture du Playbook Design Studio",           'employee', 'training',   3,  kevin,      :completed, kevin.start_date + 3.days],
  ["Formation Figma Advanced assignée",           'manager',  'training',   5,  mgr_studio, :completed, kevin.start_date + 5.days],
  ["Premier brief créatif en binôme",            'employee', 'manual',     7,  kevin,      :completed, kevin.start_date + 7.days],
  ["Bilan J14 — intégration & ressenti",         'manager',  'one_on_one', 14, mgr_studio, :pending,   nil],
  ["Première présentation client (observateur)", 'employee', 'manual',     21, kevin,      :pending,   nil],
  ["Revue qualité premier livrable solo",        'manager',  'one_on_one', 30, mgr_studio, :pending,   nil],
  ["Bilan fin période d'essai",                  'manager',  'one_on_one', 45, mgr_studio, :pending,   nil],
]

kevin_tasks.each do |title, role, type, day, assignee, status, completed_at|
  attrs = {
    employee_onboarding: ob_kevin, organization: org2,
    title: title, assigned_to_role: role, task_type: type,
    due_date: kevin.start_date + day.days,
    status: status.to_s, assigned_to: assignee
  }
  if status == :completed
    attrs.merge!(completed_at: completed_at, completed_by: assignee)
  end
  OnboardingTask.create!(attrs)
end

EmployeeOnboardingScoreRefreshJob.perform_now(ob_kevin.id)

puts "  Studio Créatif: #{org2.employees.count} employees, #{Objective.where(organization: org2).count} objectives, #{OneOnOne.where(organization: org2).count} 1:1s, #{Training.where(organization: org2).count} trainings, #{Evaluation.where(organization: org2).count} evaluations, #{EmployeeOnboarding.where(organization: org2).count} onboardings"

# ─── Résumé ───────────────────────────────────────────────────────────────────

puts "\n" + "="*60
puts "✅ Seed completed!"
puts "="*60
puts "\n📊 TechCorp France:"
puts "  Employees total:  #{Employee.where(organization: org).count}"
puts "  C-suite (admin):  #{Employee.where(organization: org, role: 'admin').count}"
puts "  HR:               #{Employee.where(organization: org, role: 'hr').count}"
puts "  Managers (cadre): #{Employee.where(organization: org, role: 'manager').count}"
puts "  Employees:        #{Employee.where(organization: org, role: 'employee').count}"
puts "  Cadre total:      #{Employee.where(organization: org).select(&:cadre?).count}"
puts "  Work schedules:   #{WorkSchedule.where(organization: org).count}"
puts "  Weekly plans:     #{WeeklySchedulePlan.where(organization: org).count}"
puts "  Leave balances:   #{LeaveBalance.where(organization: org).count}"
puts "  Leave requests:   #{LeaveRequest.where(organization: org).count}"
puts "  Objectives:       #{Objective.where(organization: org).count}"
puts "  1:1 meetings:     #{OneOnOne.where(organization: org).count}"
puts "  Trainings:        #{Training.where(organization: org).count} (#{TrainingAssignment.joins(:training).where(trainings: { organization: org }).count} assignments)"
puts "  Onboardings:      #{EmployeeOnboarding.where(organization: org).count} active"
puts "    Approved:  #{LeaveRequest.where(organization: org, status: 'approved').count}"
puts "    Pending:   #{LeaveRequest.where(organization: org, status: 'pending').count}"
puts "    Rejected:  #{LeaveRequest.where(organization: org, status: 'rejected').count}"
puts "    Cancelled: #{LeaveRequest.where(organization: org, status: 'cancelled').count}"
puts "    Auto:      #{LeaveRequest.where(organization: org, status: 'auto_approved').count}"
puts "  Time entries:     #{TimeEntry.where(organization: org).count}"

# ─── Business Rules ───────────────────────────────────────────────────────────

puts "⚙️  Creating business rules..."

[
  {
    name: "Approbation manager pour CP > 5 jours",
    trigger: "leave_request.submitted",
    conditions: [
      { "field" => "days_count", "operator" => "gt", "value" => 5 },
      { "field" => "leave_type", "operator" => "eq", "value" => "CP" }
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
  org.business_rules.create!(
    name: attrs[:name], trigger: attrs[:trigger],
    conditions: attrs[:conditions], actions: attrs[:actions],
    priority: attrs[:priority], active: attrs.fetch(:active, true),
    description: attrs[:description]
  )
end

puts "\n👤 Test accounts (all passwords: password123)"
puts "\n  🏢 TechCorp France"
puts "    CEO (admin/cadre):   admin@techcorp.fr"
puts "    COO (admin/cadre):   isabelle.moreau@techcorp.fr"
puts "    CTO (admin/cadre):   romain.blanchard@techcorp.fr"
puts "    DHR (hr/cadre):      nathalie.legrand@techcorp.fr"
puts "    HR généraliste:      camille.petit@techcorp.fr"
puts "    Lead Backend (mgr):  thomas.martin@techcorp.fr"
puts "    Lead Frontend (mgr): sophie.bernard@techcorp.fr"
puts "    Sales Manager (mgr): pierre.dubois@techcorp.fr"
puts "    Backend dev:         julien.leroy@techcorp.fr"
puts "    Frontend dev:        emma.morel@techcorp.fr"
puts "    Sales AE:            alice.dumont@techcorp.fr"
puts "    Alternant frontend:  yanis.benali@techcorp.fr"
puts "    Stagiaire backend:   ana.ferreira@techcorp.fr"
puts "\n  🏢 Studio Créatif (Manager OS — pas de SIRH)"
puts "    Admin:   admin@studio-creatif.fr"
puts "    Manager: lucas.martin@studio-creatif.fr  ← démo Manager OS"
puts "    Équipe:  camille.dupont@studio-creatif.fr"
puts "             thomas.garcia@studio-creatif.fr"
puts "             ines.benali@studio-creatif.fr"
puts "             romain.leclerc@studio-creatif.fr"
puts "             amandine.rey@studio-creatif.fr"
puts "             kevin.moreau@studio-creatif.fr"

end # ActsAsTenant.without_tenant
