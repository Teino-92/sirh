# QA Test Data Setup
# Run with: bin/rails runner db/qa_test_data.rb

# Créer 2 organisations pour tester le multi-tenancy
org1 = Organization.find_or_create_by!(name: 'TechCorp') do |o|
  o.settings = {
    work_week_hours: 35,
    cp_acquisition_rate: 2.5,
    rtt_enabled: true
  }
end

org2 = Organization.find_or_create_by!(name: 'InnoLabs') do |o|
  o.settings = {
    work_week_hours: 39,
    cp_acquisition_rate: 2.5,
    rtt_enabled: false
  }
end

# Créer admin TechCorp
admin_techcorp = Employee.find_or_create_by!(email: 'admin@techcorp.fr') do |e|
  e.organization = org1
  e.password = 'password123'
  e.password_confirmation = 'password123'
  e.first_name = 'Admin'
  e.last_name = 'TechCorp'
  e.role = 'admin'
  e.contract_type = 'CDI'
  e.start_date = Date.current - 2.years
  e.department = 'Direction'
  e.job_title = 'Directeur'
end

# Créer employé normal TechCorp
employee_techcorp = Employee.find_or_create_by!(email: 'employee@techcorp.fr') do |e|
  e.organization = org1
  e.password = 'password123'
  e.password_confirmation = 'password123'
  e.first_name = 'Jean'
  e.last_name = 'Dupont'
  e.role = 'employee'
  e.contract_type = 'CDI'
  e.start_date = Date.current - 1.year
  e.department = 'Développement'
  e.job_title = 'Développeur'
end

# Créer manager TechCorp
manager_techcorp = Employee.find_or_create_by!(email: 'manager@techcorp.fr') do |e|
  e.organization = org1
  e.password = 'password123'
  e.password_confirmation = 'password123'
  e.first_name = 'Marie'
  e.last_name = 'Martin'
  e.role = 'manager'
  e.contract_type = 'CDI'
  e.start_date = Date.current - 3.years
  e.department = 'Développement'
  e.job_title = 'Manager Développement'
end

# Créer admin InnoLabs
admin_innolabs = Employee.find_or_create_by!(email: 'admin@innolabs.fr') do |e|
  e.organization = org2
  e.password = 'password123'
  e.password_confirmation = 'password123'
  e.first_name = 'Pierre'
  e.last_name = 'Durand'
  e.role = 'admin'
  e.contract_type = 'CDI'
  e.start_date = Date.current - 1.year
  e.department = 'Direction'
  e.job_title = 'Directeur'
end

# Créer employé InnoLabs
employee_innolabs = Employee.find_or_create_by!(email: 'employee@innolabs.fr') do |e|
  e.organization = org2
  e.password = 'password123'
  e.password_confirmation = 'password123'
  e.first_name = 'Sophie'
  e.last_name = 'Bernard'
  e.role = 'employee'
  e.contract_type = 'CDD'
  e.start_date = Date.current - 6.months
  e.department = 'Marketing'
  e.job_title = 'Chargée Marketing'
end

puts '✅ Données de test créées:'
puts "TechCorp (ID: #{org1.id}):"
puts "  - admin@techcorp.fr (admin) - ID: #{admin_techcorp.id}"
puts "  - manager@techcorp.fr (manager) - ID: #{manager_techcorp.id}"
puts "  - employee@techcorp.fr (employee) - ID: #{employee_techcorp.id}"
puts "InnoLabs (ID: #{org2.id}):"
puts "  - admin@innolabs.fr (admin) - ID: #{admin_innolabs.id}"
puts "  - employee@innolabs.fr (employee) - ID: #{employee_innolabs.id}"
puts ""
puts "Mot de passe pour tous les comptes: password123"
