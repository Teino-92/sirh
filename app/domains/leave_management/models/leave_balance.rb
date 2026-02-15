# frozen_string_literal: true

class LeaveBalance < ApplicationRecord
  acts_as_tenant :organization

  belongs_to :employee

  validates :leave_type, presence: true, uniqueness: { scope: :employee_id }
  validates :balance, :accrued_this_year, :used_this_year, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :employee_belongs_to_same_organization

  # French leave types
  LEAVE_TYPES = {
    'CP' => 'Congés Payés', # Paid leave
    'RTT' => 'Réduction du Temps de Travail', # RTT days
    'Maladie' => 'Congé Maladie', # Sick leave
    'Maternite' => 'Congé Maternité', # Maternity leave
    'Paternite' => 'Congé Paternité', # Paternity leave
    'Sans_Solde' => 'Congé Sans Solde', # Unpaid leave
    'Anciennete' => 'Congés Ancienneté' # Seniority leave
  }.freeze

  validates :leave_type, inclusion: { in: LEAVE_TYPES.keys }

  scope :cp, -> { where(leave_type: 'CP') }
  scope :rtt, -> { where(leave_type: 'RTT') }
  scope :expiring_soon, -> { where('expires_at <= ?', 3.months.from_now.to_date).where.not(expires_at: nil) }

  def self.leave_type_name(type)
    LEAVE_TYPES[type]
  end

  def available_balance
    balance
  end

  def expiring_soon?
    expires_at.present? && expires_at <= 3.months.from_now.to_date
  end

  def expired?
    expires_at.present? && expires_at < Date.current
  end

  private

  def employee_belongs_to_same_organization
    return unless employee && organization_id

    if employee.organization_id != organization_id
      errors.add(:employee, 'must belong to the same organization')
    end
  end
end
