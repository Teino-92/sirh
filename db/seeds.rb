# frozen_string_literal: true

# Clear existing data
puts "🧹 Clearing existing data..."
TimeEntry.destroy_all
LeaveRequest.destroy_all
LeaveBalance.destroy_all
WorkSchedule.destroy_all
Employee.destroy_all
Organization.destroy_all

# Create organization
puts "🏢 Creating organization..."
org = Organization.create!(
  name: "TechCorp France",
  settings: {
    work_week_hours: 35,
    cp_acquisition_rate: 2.5,
    rtt_enabled: true,
    overtime_threshold: 35
  }
)

# Create HR Admin
puts "👤 Creating HR admin..."
hr_admin = org.employees.create!(
  email: "admin@techcorp.fr",
  password: "password123",
  first_name: "Marie",
  last_name: "Dubois",
  role: "hr",
  department: "Ressources Humaines",
  contract_type: "CDI",
  start_date: 2.years.ago
)

# Create Managers
puts "👔 Creating managers..."
manager1 = org.employees.create!(
  email: "thomas.martin@techcorp.fr",
  password: "password123",
  first_name: "Thomas",
  last_name: "Martin",
  role: "manager",
  department: "Engineering",
  contract_type: "CDI",
  start_date: 1.year.ago
)

manager2 = org.employees.create!(
  email: "sophie.bernard@techcorp.fr",
  password: "password123",
  first_name: "Sophie",
  last_name: "Bernard",
  role: "manager",
  department: "Sales",
  contract_type: "CDI",
  start_date: 1.year.ago
)

# Create Employees
puts "👥 Creating employees..."
employees_data = [
  { email: "julien.petit@techcorp.fr", first_name: "Julien", last_name: "Petit", department: "Engineering", manager: manager1 },
  { email: "camille.durand@techcorp.fr", first_name: "Camille", last_name: "Durand", department: "Engineering", manager: manager1 },
  { email: "lucas.moreau@techcorp.fr", first_name: "Lucas", last_name: "Moreau", department: "Engineering", manager: manager1 },
  { email: "emma.laurent@techcorp.fr", first_name: "Emma", last_name: "Laurent", department: "Sales", manager: manager2 },
  { email: "hugo.simon@techcorp.fr", first_name: "Hugo", last_name: "Simon", department: "Sales", manager: manager2 }
]

employees = employees_data.map do |data|
  org.employees.create!(
    email: data[:email],
    password: "password123",
    first_name: data[:first_name],
    last_name: data[:last_name],
    role: "employee",
    department: data[:department],
    manager: data[:manager],
    contract_type: "CDI",
    start_date: 6.months.ago
  )
end

all_employees = [hr_admin, manager1, manager2] + employees

# Create work schedules
puts "📅 Creating work schedules..."
all_employees.each do |employee|
  if [0, 1, 2].include?(all_employees.index(employee))
    # Full-time 35h for HR and managers
    WorkSchedule.create_from_template(employee, 'full_time_35h')
  elsif [3, 4].include?(all_employees.index(employee))
    # Full-time 39h with RTT for some employees
    WorkSchedule.create_from_template(employee, 'full_time_39h')
  else
    # Standard 35h for others
    WorkSchedule.create_from_template(employee, 'full_time_35h')
  end
end

# Initialize leave balances
puts "🏖️ Initializing leave balances..."
all_employees.each do |employee|
  # Calculate CP balance based on tenure
  months_worked = ((Date.current - employee.start_date) / 30).to_i
  cp_balance = [months_worked * 2.5, 30].min # 2.5 days per month, max 30 days

  # Create CP balance
  LeaveBalance.create!(
    employee: employee,
    leave_type: 'CP',
    balance: cp_balance,
    accrued_this_year: cp_balance,
    used_this_year: 0,
    expires_at: Date.new(Date.current.year + 1, 5, 31) # May 31st next year
  )

  # Create RTT balance if applicable
  if employee.work_schedule.rtt_eligible?
    LeaveBalance.create!(
      employee: employee,
      leave_type: 'RTT',
      balance: 5.0, # Initial RTT balance
      accrued_this_year: 5.0,
      used_this_year: 0
    )
  end

  # Other leave types
  LeaveBalance.create!(
    employee: employee,
    leave_type: 'Maladie',
    balance: 0,
    accrued_this_year: 0,
    used_this_year: 0
  )
end

# Create some leave requests
puts "📝 Creating leave requests..."

# Approved leave request
LeaveRequest.create!(
  employee: employees[0],
  leave_type: 'CP',
  start_date: 1.week.from_now,
  end_date: 1.week.from_now + 4.days,
  days_count: 5,
  status: 'approved',
  approved_by: manager1,
  approved_at: Time.current,
  reason: "Vacances d'été"
)

# Pending leave request
LeaveRequest.create!(
  employee: employees[1],
  leave_type: 'CP',
  start_date: 2.weeks.from_now,
  end_date: 2.weeks.from_now + 2.days,
  days_count: 3,
  status: 'pending',
  reason: "Congés personnels"
)

# Auto-approved short leave
LeaveRequest.create!(
  employee: employees[2],
  leave_type: 'CP',
  start_date: Date.tomorrow,
  end_date: Date.tomorrow,
  days_count: 1,
  status: 'auto_approved',
  approved_at: Time.current,
  reason: "Rendez-vous médical"
)

# Create time entries for this week
puts "⏰ Creating time entries..."
employees.each do |employee|
  # Monday to today
  (Date.current.beginning_of_week..Date.current - 1.day).each do |date|
    next if date.saturday? || date.sunday?

    clock_in = date.to_time + 9.hours
    clock_out = clock_in + 8.hours

    TimeEntry.create!(
      employee: employee,
      clock_in: clock_in,
      clock_out: clock_out,
      duration_minutes: 480, # 8 hours
      manual_override: false
    )
  end

  # Today - some employees are currently working
  if [employees[0], employees[1]].include?(employee)
    TimeEntry.create!(
      employee: employee,
      clock_in: Date.current.to_time + 9.hours,
      clock_out: nil, # Still clocked in
      manual_override: false
    )
  end
end

puts "\n✅ Seed data created successfully!"
puts "\n📊 Summary:"
puts "  - Organization: #{Organization.count}"
puts "  - Employees: #{Employee.count}"
puts "    - HR/Admin: #{Employee.where(role: %w[hr admin]).count}"
puts "    - Managers: #{Employee.where(role: 'manager').count}"
puts "    - Employees: #{Employee.where(role: 'employee').count}"
puts "  - Work Schedules: #{WorkSchedule.count}"
puts "  - Leave Balances: #{LeaveBalance.count}"
puts "  - Leave Requests: #{LeaveRequest.count}"
puts "  - Time Entries: #{TimeEntry.count}"

puts "\n👤 Test Accounts:"
puts "  HR Admin:"
puts "    Email: admin@techcorp.fr"
puts "    Password: password123"
puts "\n  Manager (Engineering):"
puts "    Email: thomas.martin@techcorp.fr"
puts "    Password: password123"
puts "\n  Employee:"
puts "    Email: julien.petit@techcorp.fr"
puts "    Password: password123"
