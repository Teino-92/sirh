class Evaluation < ApplicationRecord
  include SameOrganizationValidatable

  # Multi-tenancy
  belongs_to :organization
  acts_as_tenant :organization

  # Core relationships
  belongs_to :employee, class_name: 'Employee'
  belongs_to :manager, class_name: 'Employee'
  belongs_to :created_by, class_name: 'Employee'

  # Optional relationships (loose coupling)
  has_many :evaluation_objectives, dependent: :destroy
  has_many :objectives, through: :evaluation_objectives
  has_many :evaluation_trainings, dependent: :destroy
  has_many :training_assignments, through: :evaluation_trainings

  # Enums
  enum status: {
    draft: 'draft',
    employee_review_pending: 'employee_review_pending',
    manager_review_pending: 'manager_review_pending',
    completed: 'completed',
    cancelled: 'cancelled'
  }

  enum score: {
    insufficient: 1,
    below_expectations: 2,
    meets_expectations: 3,
    exceeds_expectations: 4,
    exceptional: 5
  }, _prefix: true

  # Validations
  validates :period_start, presence: true
  validates :period_end, presence: true
  validates :status, presence: true
  validate :period_end_after_start
  validate :manager_is_manager_role
  validate_same_organization :employee, :manager

  # Scopes
  scope :active, -> { where(status: [:draft, :employee_review_pending, :manager_review_pending]) }
  scope :completed_this_year, -> { where(status: :completed).where('period_end >= ?', Date.current.beginning_of_year) }
  scope :for_manager, ->(manager) { where(manager: manager) }
  scope :for_employee, ->(employee) { where(employee: employee) }
  scope :by_period, ->(year) { where('EXTRACT(YEAR FROM period_end) = ?', year) }

  # Instance methods
  def complete!(final_score: nil)
    return if completed?
    transaction do
      update!(
        status: :completed,
        completed_at: Time.current,
        score: final_score
      )
    end
  end

  def advance_to_manager_review!(self_review_text:)
    return if manager_review_pending? || completed?
    transaction do
      update!(self_review: self_review_text, status: :manager_review_pending)
    end
  end

  def self_review_submitted?
    self_review.present?
  end

  def manager_review_submitted?
    manager_review.present?
  end

  def fully_reviewed?
    self_review_submitted? && manager_review_submitted?
  end

  # Criteria scores — stored in metadata[:criteria_scores]
  # Format: [{ "name" => "Qualité du travail", "score" => 4 }, ...]
  def criteria_scores
    (metadata["criteria_scores"] || []).map do |c|
      { "name" => c["name"].to_s, "score" => c["score"].to_i }
    end
  end

  def criteria_scores=(entries)
    valid = Array(entries)
      .reject { |c| c["name"].to_s.strip.blank? }
      .map { |c| { "name" => c["name"].to_s.strip, "score" => c["score"].to_i.clamp(0, 5) } }
    self.metadata = metadata.merge("criteria_scores" => valid)
  end

  def average_score
    scores = criteria_scores.map { |c| c["score"] }
    return nil if scores.empty?
    (scores.sum.to_f / scores.size).round(1)
  end

  private

  def period_end_after_start
    return unless period_start.present? && period_end.present?
    return if period_end > period_start

    errors.add(:period_end, 'must be after period start')
  end

  def manager_is_manager_role
    return unless manager.present?
    return if manager.manager? || manager.hr_or_admin?

    errors.add(:manager, 'must have manager or HR role')
  end

end
