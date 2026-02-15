# frozen_string_literal: true

# Job pour l'acquisition automatique des congés payés (CP)
# Exécuté mensuellement (1er du mois) pour tous les employés actifs
# Calcule et ajoute les CP selon le Code du travail français (2.5 jours/mois)
class LeaveAccrualJob < ApplicationJob
  queue_as :default

  # Traiter tous les employés actifs de toutes les organisations
  def perform
    Rails.logger.info "[LeaveAccrualJob] Début du traitement mensuel des CP - #{Date.current}"

    total_processed = 0
    total_errors = 0

    # Parcourir toutes les organisations
    Organization.find_each do |organization|
      ActsAsTenant.with_tenant(organization) do
        process_organization_employees(organization)
      end
    rescue => e
      Rails.logger.error "[LeaveAccrualJob] Erreur organisation #{organization.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      total_errors += 1
    end

    Rails.logger.info "[LeaveAccrualJob] Traitement terminé - Traités: #{total_processed}, Erreurs: #{total_errors}"
  end

  private

  def process_organization_employees(organization)
    Rails.logger.info "[LeaveAccrualJob] Traitement organisation: #{organization.name} (ID: #{organization.id})"

    # Récupérer tous les employés actifs (sans date de fin ou date de fin future)
    active_employees = Employee.where(organization: organization)
                               .where('end_date IS NULL OR end_date > ?', Date.current)

    Rails.logger.info "[LeaveAccrualJob] #{active_employees.count} employés actifs trouvés"

    active_employees.find_each do |employee|
      process_employee(employee, organization)
    rescue => e
      Rails.logger.error "[LeaveAccrualJob] Erreur employé #{employee.id} (#{employee.email}): #{e.message}"
    end
  end

  def process_employee(employee, organization)
    ActiveRecord::Base.transaction do
      # Calculer l'acquisition mensuelle via le moteur de conformité
      engine = LeaveManagement::Services::LeavePolicyEngine.new(employee)
      monthly_accrual = engine.get_setting(:cp_acquisition_rate)

      # Ajuster pour temps partiel si applicable
      if employee.respond_to?(:part_time_ratio) && employee.part_time_ratio.present? && employee.part_time_ratio < 1.0
        monthly_accrual = monthly_accrual * employee.part_time_ratio
      end

      # Récupérer ou créer le solde CP
      cp_balance = LeaveBalance.find_or_create_by!(
        employee: employee,
        organization: organization,
        leave_type: 'CP'
      ) do |balance|
        balance.balance = 0
        balance.accrued_this_year = 0
        balance.used_this_year = 0
      end

      # Vérifier qu'on ne dépasse pas le maximum annuel
      max_annual = engine.get_setting(:cp_max_annual)
      new_balance = cp_balance.balance + monthly_accrual

      if new_balance > max_annual
        monthly_accrual = [max_annual - cp_balance.balance, 0].max
        Rails.logger.info "[LeaveAccrualJob] Plafond atteint pour #{employee.email} - Acquisition limitée à #{monthly_accrual} jours"
      end

      # Mettre à jour le solde
      cp_balance.balance += monthly_accrual
      cp_balance.accrued_this_year += monthly_accrual

      # Définir la date d'expiration (31 mai de l'année prochaine selon Code du travail)
      expiry_month = engine.get_setting(:cp_expiry_month)
      expiry_day = engine.get_setting(:cp_expiry_day)
      next_year = Date.current.year + 1
      cp_balance.expires_at = Date.new(next_year, expiry_month, expiry_day)

      cp_balance.save!
      Rails.logger.info "[LeaveAccrualJob] ✓ #{employee.email}: +#{monthly_accrual.round(2)} jours CP (Total: #{cp_balance.balance.round(2)})"
    end
  rescue => e
    Rails.logger.error "[LeaveAccrualJob] ✗ Erreur pour #{employee.email}: #{e.message}"
  end
end
