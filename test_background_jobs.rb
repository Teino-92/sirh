#!/usr/bin/env ruby
# Script de test des background jobs
# Usage: bin/rails runner test_background_jobs.rb

puts "="*80
puts "Test des Background Jobs - Easy-RH"
puts "Date: #{Date.current}"
puts "="*80
puts ""

# 1. Test LeaveAccrualJob
puts "### Test 1: LeaveAccrualJob (Acquisition mensuelle CP)"
puts "-"*80

# Afficher l'état actuel
org = Organization.first
ActsAsTenant.with_tenant(org) do
  employee = Employee.where(organization: org).first

  puts "Organisation: #{org.name}"
  puts "Employé de test: #{employee&.full_name} (#{employee&.email})"

  if employee
    cp_balance_before = LeaveBalance.find_by(employee: employee, leave_type: 'CP')
    puts "\nSolde CP AVANT:"
    if cp_balance_before
      puts "  Balance: #{cp_balance_before.balance.round(2)} jours"
      puts "  Acquis cette année: #{cp_balance_before.accrued_this_year.round(2)} jours"
    else
      puts "  Aucun solde CP existant"
    end

    puts "\nExécution du job..."
    LeaveAccrualJob.perform_now

    puts "\nSolde CP APRÈS:"
    cp_balance_after = LeaveBalance.find_by(employee: employee, leave_type: 'CP')
    if cp_balance_after
      puts "  Balance: #{cp_balance_after.balance.round(2)} jours"
      puts "  Acquis cette année: #{cp_balance_after.accrued_this_year.round(2)} jours"
      puts "  Expire le: #{cp_balance_after.expires_at}"

      if cp_balance_before
        diff = cp_balance_after.balance - cp_balance_before.balance
        puts "\n  ✅ Différence: +#{diff.round(2)} jours"
      end
    end
  else
    puts "⚠️  Aucun employé trouvé dans l'organisation"
  end
end

puts "\n"
puts "="*80
puts ""

# 2. Test RttAccrualJob
puts "### Test 2: RttAccrualJob (Calcul hebdomadaire RTT)"
puts "-"*80

ActsAsTenant.with_tenant(org) do
  employee = Employee.where(organization: org).first

  if employee && org.rtt_enabled?
    # Créer des time entries de test si aucune n'existe
    week_start = Date.current.beginning_of_week
    week_end = week_start.end_of_week

    time_entries = TimeEntry.where(employee: employee)
                           .where('DATE(clock_in) BETWEEN ? AND ?', week_start, week_end)
                           .completed

    puts "Organisation: #{org.name} (RTT activé: #{org.rtt_enabled?})"
    puts "Employé: #{employee.full_name}"
    puts "Semaine: #{week_start} au #{week_end}"
    puts "Time entries cette semaine: #{time_entries.count}"

    total_minutes = time_entries.sum(:duration_minutes) || 0.0
    total_hours = total_minutes / 60.0
    puts "Total heures travaillées: #{total_hours.round(2)}h"

    rtt_balance_before = LeaveBalance.find_by(employee: employee, leave_type: 'RTT')
    puts "\nSolde RTT AVANT:"
    if rtt_balance_before
      puts "  Balance: #{rtt_balance_before.balance.round(2)} jours"
    else
      puts "  Aucun solde RTT existant"
    end

    puts "\nExécution du job..."
    RttAccrualJob.perform_now(week_start)

    puts "\nSolde RTT APRÈS:"
    rtt_balance_after = LeaveBalance.find_by(employee: employee, leave_type: 'RTT')
    if rtt_balance_after
      puts "  Balance: #{rtt_balance_after.balance.round(2)} jours"

      if rtt_balance_before
        diff = rtt_balance_after.balance - rtt_balance_before.balance
        if diff > 0
          puts "\n  ✅ Différence: +#{diff.round(2)} jours RTT"
        else
          puts "\n  ⚠️  Pas de RTT accordé (heures < 35h ou pas de time entries)"
        end
      end
    end
  elsif !org.rtt_enabled?
    puts "⚠️  RTT désactivé pour cette organisation"
  else
    puts "⚠️  Aucun employé trouvé"
  end
end

puts "\n"
puts "="*80
puts ""

# 3. Résumé
puts "### Résumé des Tests"
puts "-"*80

ActsAsTenant.with_tenant(org) do
  cp_balances = LeaveBalance.where(leave_type: 'CP')
  rtt_balances = LeaveBalance.where(leave_type: 'RTT')

  puts "Total balances CP: #{cp_balances.count}"
  puts "Total balances RTT: #{rtt_balances.count}"

  if cp_balances.any?
    puts "\nTop 5 soldes CP:"
    cp_balances.order(balance: :desc).limit(5).each do |balance|
      puts "  - #{balance.employee.full_name}: #{balance.balance.round(2)} jours"
    end
  end

  if rtt_balances.any?
    puts "\nTop 5 soldes RTT:"
    rtt_balances.order(balance: :desc).limit(5).each do |balance|
      puts "  - #{balance.employee.full_name}: #{balance.balance.round(2)} jours"
    end
  end
end

puts "\n"
puts "="*80
puts "✅ Tests terminés!"
puts "="*80
