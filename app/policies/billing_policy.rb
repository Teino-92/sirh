# frozen_string_literal: true

# BillingPolicy — autorise l'accès aux actions de facturation.
# record = Organization (l'org courante)
# user   = current_employee (via pundit_user dans ApplicationController)

class BillingPolicy < ApplicationPolicy
  # Tout employé de l'org peut consulter l'état de l'abonnement
  def show?
    user.organization_id == record.id
  end

  # Seuls HR et Admin peuvent créer un checkout, upgrader ou résilier
  def create_checkout?
    user.organization_id == record.id && user.hr_or_admin?
  end

  def upgrade?
    user.organization_id == record.id && user.hr_or_admin?
  end

  def request_upgrade?
    user.organization_id == record.id && user.hr_or_admin?
  end

  def cancel?
    user.organization_id == record.id && user.hr_or_admin?
  end

  def success?
    user.organization_id == record.id
  end
end
