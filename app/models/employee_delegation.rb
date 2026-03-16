# frozen_string_literal: true

# Allows an employee to temporarily delegate their approval role to a colleague.
#
# Example: a manager going on leave delegates their "manager" approval role to
# their deputy for the duration of the absence.
#
# The delegator retains their own approval rights — delegation is additive.
class EmployeeDelegation < ApplicationRecord
  acts_as_tenant :organization

  belongs_to :organization
  belongs_to :delegator, class_name: 'Employee'
  belongs_to :delegatee, class_name: 'Employee'

  validates :role,      presence: true, inclusion: { in: Employee::ROLES }
  validates :starts_at, presence: true
  validates :ends_at,   presence: true

  validate :ends_at_after_starts_at
  validate :delegator_has_role
  validate :not_self_delegation
  validate :not_a_direct_report

  scope :active_now,    -> { where(active: true).where('starts_at <= ? AND ends_at >= ?', Time.current, Time.current) }
  scope :for_delegatee, ->(employee) { where(delegatee: employee) }

  private

  def ends_at_after_starts_at
    return unless starts_at && ends_at
    errors.add(:ends_at, "doit être postérieure à starts_at") if ends_at <= starts_at
  end

  def delegator_has_role
    return unless delegator && role
    unless delegator.role == role || delegator.admin?
      errors.add(:role, "le délégant ne possède pas le rôle '#{role}'")
    end
  end

  def not_self_delegation
    return unless delegator_id && delegatee_id
    errors.add(:delegatee, "ne peut pas être le délégant lui-même") if delegator_id == delegatee_id
  end

  def not_a_direct_report
    return unless delegator && delegatee
    if delegatee.manager_id == delegator.id
      errors.add(:delegatee, "ne peut pas être un membre de votre équipe — choisissez un pair ou un supérieur")
    end
  end
end
