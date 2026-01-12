#!/usr/bin/env ruby
# Test workflow complet de demande de congé

ActsAsTenant.current_tenant = Organization.first

# Récupérer les employés
employee = Employee.find_by(email: 'julien.petit@techcorp.fr')
manager = employee.manager

puts '=== Test Workflow Demande de Congé ==='
puts "Employé: #{employee.full_name} (#{employee.email})"
puts "Manager: #{manager.full_name} (#{manager.email})"
puts ""

# Étape 1: Récupérer une demande de congé existante ou créer une nouvelle
puts '=== Étape 1: Demande de congé ==='
leave_request = LeaveRequest.where(employee: employee, status: 'pending').first

if leave_request
  puts "📋 Utilisation demande existante: ID=#{leave_request.id}"
else
  leave_request = LeaveRequest.create!(
    employee: employee,
    leave_type: 'cp',
    start_date: Date.current + 7.days,
    end_date: Date.current + 10.days,
    days_count: 4,
    reason: 'Vacances en famille - Test workflow'
  )
  puts "✅ Nouvelle demande créée: ID=#{leave_request.id}"
end

puts "Status: #{leave_request.status}"
puts ""

# Étape 2: Vérifier les notifications créées
puts '=== Étape 2: Vérifications notifications ==='
notifications = Notification.where(employee: manager, leave_request: leave_request)
puts "Notifications créées pour le manager: #{notifications.count}"
if notifications.any?
  notifications.each do |notif|
    puts "  - Type: #{notif.notification_type}, Lu: #{notif.read}, Message: #{notif.message}"
  end
else
  puts "  ⚠️ AUCUNE notification créée!"
end
puts ""

# Étape 3: Vérifier les jobs en queue
puts '=== Étape 3: Jobs en queue (Solid Queue) ==='
pending_jobs = SolidQueue::Job.where(finished_at: nil).count
puts "Jobs en attente: #{pending_jobs}"
if pending_jobs > 0
  SolidQueue::Job.where(finished_at: nil).limit(5).each do |job|
    puts "  - Job: #{job.class_name}, Arguments: #{job.arguments.inspect}"
  end
end
puts ""

# Étape 4: Simuler l'approbation
puts '=== Étape 4: Approbation de la demande ==='
ActsAsTenant.with_tenant(manager.organization) do
  leave_request.approved_by = manager
  leave_request.status = 'approved'
  leave_request.save!
end
puts "✅ Demande approuvée par #{manager.full_name}"
puts "Status final: #{leave_request.reload.status}"
puts ""

# Étape 5: Vérifier les notifications pour l'employé
puts '=== Étape 5: Notifications employé après approbation ==='
employee_notifications = Notification.where(employee: employee, leave_request: leave_request)
puts "Notifications créées pour l'employé: #{employee_notifications.count}"
if employee_notifications.any?
  employee_notifications.each do |notif|
    puts "  - Type: #{notif.notification_type}, Lu: #{notif.read}, Message: #{notif.message}"
  end
else
  puts "  ⚠️ AUCUNE notification créée pour l'employé!"
end
puts ""

# Étape 6: Vérifier les jobs après approbation
puts '=== Étape 6: Nouveaux jobs après approbation ==='
new_pending_jobs = SolidQueue::Job.where(finished_at: nil).count
puts "Jobs en attente maintenant: #{new_pending_jobs}"
puts ""

puts '=== Résumé ==='
puts "Demande ID: #{leave_request.id}"
puts "Status: #{leave_request.status}"
puts "Notifications manager: #{notifications.count}"
puts "Notifications employé: #{employee_notifications.count}"
puts "Jobs total en queue: #{new_pending_jobs}"
puts ""
puts '✅ Test workflow terminé!'
