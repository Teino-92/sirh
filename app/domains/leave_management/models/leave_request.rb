# frozen_string_literal: true

class LeaveRequest < ApplicationRecord
  has_paper_trail on: %i[create update destroy],
                  meta: { organization_id: :organization_id }

  acts_as_tenant :organization

  belongs_to :employee
  belongs_to :approved_by, class_name: 'Employee', optional: true

  validates :leave_type, :start_date, :end_date, :days_count, :status, presence: true
  validates :leave_type, inclusion: { in: LeaveBalance::LEAVE_TYPES.keys }
  validates :status, inclusion: { in: %w[pending approved rejected cancelled auto_approved] }
  validate :end_date_after_start_date
  validate :sufficient_balance, on: :create
  validate :employee_belongs_to_same_organization
  validate :approver_belongs_to_same_organization
  validate :period_not_locked, on: %i[create update]

  scope :pending, -> { where(status: 'pending') }
  scope :approved, -> { where(status: %w[approved auto_approved]) }
  scope :rejected, -> { where(status: 'rejected') }
  scope :for_date_range, ->(start_date, end_date) do
    where('leave_requests.start_date <= ? AND leave_requests.end_date >= ?', end_date, start_date)
  end
  scope :for_employee, ->(employee_id) { where(employee_id: employee_id) }
  scope :for_team, ->(manager) { where(employee: manager.team_members) }

  after_create :notify_manager
  after_update :update_leave_balance, if: :saved_change_to_status?

  def approve!(approver)
    ActiveRecord::Base.transaction do
      update!(
        status: 'approved',
        approved_by: approver,
        approved_at: Time.current
      )
    end
  end

  def reject!(approver, reason: nil)
    ActiveRecord::Base.transaction do
      update!(
        status: 'rejected',
        approved_by: approver,
        approved_at: Time.current,
        rejection_reason: reason
      )
    end
  end

  def auto_approve!
    update!(
      status: 'auto_approved',
      approved_at: Time.current
    )
  end

  def approved?
    %w[approved auto_approved].include?(status)
  end

  def pending?
    status == 'pending'
  end

  def conflicts_with_team?
    # Check if there are team coverage issues
    return false unless employee.manager

    employee.manager.team_members
      .joins(:leave_requests)
      .merge(LeaveRequest.approved.for_date_range(start_date, end_date))
      .where.not(id: employee.id)
      .exists?
  end

  private

  def end_date_after_start_date
    return if end_date.blank? || start_date.blank?

    errors.add(:end_date, 'must be after start date') if end_date < start_date
  end

  def sufficient_balance
    return unless employee && leave_type

    balance = employee.leave_balances.find_by(leave_type: leave_type)
    return unless balance

    if balance.balance < days_count
      errors.add(:base, "Insufficient #{leave_type} balance. Available: #{balance.balance} days")
    end
  end

  def notify_manager
    # TODO: Send notification to manager
    # LeaveRequestMailer.notify_manager(self).deliver_later
  end

  def update_leave_balance
    return unless approved?

    ActiveRecord::Base.transaction do
      balance = employee.leave_balances.find_by(leave_type: leave_type)
      raise "Balance not found for #{leave_type}" unless balance

      balance.update!(
        balance: balance.balance - days_count,
        used_this_year: balance.used_this_year + days_count
      )
    end
  end

  def employee_belongs_to_same_organization
    return unless employee && organization_id

    if employee.organization_id != organization_id
      errors.add(:employee, 'must belong to the same organization')
    end
  end

  def approver_belongs_to_same_organization
    return unless approved_by && organization_id

    if approved_by.organization_id != organization_id
      errors.add(:approved_by, 'must belong to the same organization')
    end
  end

  def period_not_locked
    return unless start_date.present? && organization_id.present?

    if PayrollPeriod.locked?(organization_id, start_date)
      errors.add(:base, "La période #{start_date.strftime('%B %Y')} est clôturée.")
    end
  end
end
