# frozen_string_literal: true

class EmployeeOnboarding < ApplicationRecord
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
  validate  :employee_and_manager_in_same_org
  validate  :template_same_organization

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
    onboarding_tasks.pending.where('due_date < ?', Date.current)
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

  def employee_and_manager_in_same_org
    return unless employee && manager

    unless employee.organization_id == manager.organization_id
      errors.add(:base, "L'employé et le manager doivent appartenir à la même organisation")
    end
  end

  def template_same_organization
    return unless onboarding_template.present?
    return if onboarding_template.organization_id == organization_id

    errors.add(:onboarding_template_id, "doit appartenir à la même organisation")
  end
end
