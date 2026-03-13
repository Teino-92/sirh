# frozen_string_literal: true

# Initialise les soldes de congés pour un nouvel employé.
# Appelé à la création d'un employé (admin ou onboarding).
#
# Types créés systématiquement :
#   - CP  : obligatoire pour tous les salariés français
#   - RTT : uniquement si l'organisation a activé l'RTT (rtt_enabled?)
#
# Les autres types (Maladie, Maternite, etc.) sont créés à la demande
# lors de la première demande de congés de ce type.

class LeaveBalanceInitializer
  def initialize(employee)
    @employee = employee
    @organization = employee.organization
  end

  def initialize_balances
    ActsAsTenant.with_tenant(@organization) do
      ActiveRecord::Base.transaction do
        create_balance('CP')
        create_balance('RTT') if @organization.rtt_enabled?
      end
    end
  end

  private

  def create_balance(leave_type)
    @employee.leave_balances.find_or_create_by!(leave_type: leave_type) do |b|
      b.balance          = 0
      b.accrued_this_year = 0
      b.used_this_year   = 0
      b.organization     = @organization
    end
  end
end
