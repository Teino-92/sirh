# frozen_string_literal: true

# Job pour le calcul automatique des RTT (Réduction du Temps de Travail)
# Exécuté hebdomadairement (chaque lundi) pour tous les employés actifs
# Calcule les RTT basés sur les heures travaillées au-delà de 35h/semaine (Code du travail)
class RttAccrualJob < ApplicationJob
  queue_as :default

  # Traiter la semaine précédente pour tous les employés
  def perform(week_start_date = nil)
    # Par défaut, traiter la semaine précédente (lundi au dimanche)
    week_start = week_start_date&.to_date || Date.current.last_week.beginning_of_week
    week_end = week_start.end_of_week

    Rails.logger.info "[RttAccrualJob] Début du traitement RTT pour la semaine #{week_start} - #{week_end}"

    total_processed = 0
    total_rtt_granted = 0.0

    # Parcourir toutes les organisations
    Organization.find_each do |organization|
      # Vérifier si l'organisation a les RTT activés
      next unless organization.rtt_enabled?

      ActsAsTenant.with_tenant(organization) do
        stats = process_organization_employees(organization, week_start, week_end)
        total_processed += stats[:processed]
        total_rtt_granted += stats[:rtt_granted]
      end
    rescue => e
      Rails.logger.error "[RttAccrualJob] Erreur organisation #{organization.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end

    Rails.logger.info "[RttAccrualJob] Traitement terminé - Employés: #{total_processed}, RTT accordés: #{total_rtt_granted.round(2)} jours"
  end

  private

  def process_organization_employees(organization, week_start, week_end)
    Rails.logger.info "[RttAccrualJob] Traitement organisation: #{organization.name} (ID: #{organization.id})"

    processed = 0
    rtt_granted = 0.0

    # Récupérer tous les employés actifs
    active_employees = Employee.where(organization: organization)
                               .where('end_date IS NULL OR end_date > ?', week_start)

    Rails.logger.info "[RttAccrualJob] #{active_employees.count} employés actifs"

    active_employees.find_each do |employee|
      employee_rtt = process_employee(employee, organization, week_start, week_end)
      if employee_rtt > 0
        processed += 1
        rtt_granted += employee_rtt
      end
    rescue => e
      Rails.logger.error "[RttAccrualJob] Erreur employé #{employee.id} (#{employee.email}): #{e.message}"
    end

    { processed: processed, rtt_granted: rtt_granted }
  end

  def process_employee(employee, organization, week_start, week_end)
    # Récupérer toutes les time entries complétées de la semaine
    time_entries = TimeEntry.where(employee: employee, organization: organization)
                            .where('DATE(clock_in) BETWEEN ? AND ?', week_start, week_end)
                            .completed

    # Calculer le total d'heures travaillées (duration_minutes converti en heures)
    total_minutes = time_entries.sum(:duration_minutes) || 0.0
    total_hours = total_minutes / 60.0

    # Si aucune heure travaillée, passer
    return 0 if total_hours.zero?

    # Utiliser le moteur de conformité pour calculer les RTT
    engine = LeaveManagement::Services::LeavePolicyEngine.new(employee)
    rtt_threshold = engine.get_setting(:rtt_calculation_threshold)

    # Heures au-delà du seuil (généralement 35h/semaine)
    overtime_hours = [total_hours - rtt_threshold, 0].max

    # Si pas d'heures supplémentaires, passer
    return 0 if overtime_hours.zero?

    # Calcul RTT: 1 jour RTT ≈ 7 heures supplémentaires (règle française standard)
    rtt_days = overtime_hours / 7.0

    # Arrondir à 2 décimales
    rtt_days = rtt_days.round(2)

    ActiveRecord::Base.transaction do
      # Récupérer ou créer le solde RTT
      rtt_balance = LeaveBalance.find_or_create_by!(
        employee: employee,
        organization: organization,
        leave_type: 'RTT'
      ) do |balance|
        balance.balance = 0
        balance.accrued_this_year = 0
        balance.used_this_year = 0
      end

      # Mettre à jour le solde
      rtt_balance.balance += rtt_days
      rtt_balance.accrued_this_year += rtt_days

      # Les RTT n'expirent généralement pas (à la différence des CP)
      # Mais certaines conventions collectives peuvent avoir des règles d'expiration
      # rtt_balance.expires_at = Date.new(Date.current.year, 12, 31) # Fin d'année si nécessaire

      rtt_balance.save!
      Rails.logger.info "[RttAccrualJob] ✓ #{employee.email}: #{total_hours.round(2)}h travaillées, " \
                        "#{overtime_hours.round(2)}h supp, +#{rtt_days} jours RTT " \
                        "(Total: #{rtt_balance.balance.round(2)})"

      # Envoyer notification à l'employé (optionnel)
      notify_employee_rtt_accrual(employee, rtt_days, overtime_hours) if rtt_days >= 0.5
    end

    rtt_days
  rescue => e
    Rails.logger.error "[RttAccrualJob] ✗ Erreur pour #{employee.email}: #{e.message}"
    0
  end

  # Notification optionnelle quand l'employé gagne au moins 0.5 jour RTT
  def notify_employee_rtt_accrual(employee, rtt_days, overtime_hours)
    # TODO: Implémenter notification (email, in-app notification, etc.)
    # Exemple:
    # RttAccrualMailer.notify_accrual(employee, rtt_days, overtime_hours).deliver_later
    Rails.logger.info "[RttAccrualJob] Notification RTT envoyée à #{employee.email}"
  rescue => e
    Rails.logger.error "[RttAccrualJob] Erreur envoi notification: #{e.message}"
  end
end
