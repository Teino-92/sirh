# frozen_string_literal: true

class EmployeeOnboarding < ApplicationRecord
  include SameOrganizationValidatable

  self.table_name = 'employee_onboardings'

  has_paper_trail on: %i[create update],
                  meta: { organization_id: :organization_id }

  belongs_to :organization
  acts_as_tenant :organization

  belongs_to :employee,             class_name: 'Employee'
  belongs_to :manager,              class_name: 'Employee'
  belongs_to :onboarding_template

  has_many :onboarding_tasks,   dependent: :destroy, foreign_key: :employee_onboarding_id
  has_many :onboarding_reviews, dependent: :destroy, foreign_key: :employee_onboarding_id

  enum status: {
    active:    'active',
    completed: 'completed',
    cancelled: 'cancelled'
  }

  validates :start_date,   presence: true
  validates :end_date,     presence: true
  validates :employee_id,  uniqueness: { conditions: -> { where(status: 'active') },
                                         message: "a déjà un onboarding actif en cours" }
  validate  :end_date_after_start_date
  validate  :manager_has_manager_role
  validate_same_organization :employee, :manager, :onboarding_template

  scope :active,       -> { where(status: 'active') }
  scope :for_manager,  ->(m) { where(manager: m) }
  scope :for_employee, ->(e) { where(employee: e) }

  def progress_percentage
    return progress_percentage_cache if progress_percentage_cache.positive?

    EmployeeOnboardingProgressCalculatorService.new(self).call
  end

  def integration_score
    return integration_score_cache if integration_score_cache.positive?

    EmployeeOnboardingIntegrationScoreService.new(self).call
  end

  def day_number
    (Date.current - start_date).to_i + 1
  end

  def overdue_tasks
    # Use in-memory filter when tasks are already loaded (avoids N+1 in list views)
    if onboarding_tasks.loaded?
      onboarding_tasks.select { |t| t.status.to_s == 'pending' && t.due_date.present? && t.due_date < Date.current }
    else
      onboarding_tasks.pending.where('due_date < ?', Date.current)
    end
  end

  def complete!
    return if completed?

    transaction do
      update!(status: :completed)
    end
  end

  private

  def end_date_after_start_date
    return unless start_date && end_date

    errors.add(:end_date, 'doit être après la date de début') if end_date <= start_date
  end

  def manager_has_manager_role
    return unless manager

    errors.add(:manager, "doit avoir le rôle manager") unless manager.manager?
  end

end
