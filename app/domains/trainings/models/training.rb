class Training < ApplicationRecord
  # Multi-tenancy
  belongs_to :organization
  acts_as_tenant :organization

  # Assignments
  has_many :training_assignments, dependent: :destroy
  has_many :employees, through: :training_assignments

  # Optional link to evaluations (through training_assignments)
  has_many :evaluations, through: :training_assignments, source: :evaluations

  # Enums
  enum training_type: {
    internal: 'internal',
    external: 'external',
    certification: 'certification',
    e_learning: 'e_learning',
    mentoring: 'mentoring'
  }

  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 5000 }
  validates :training_type, presence: true
  validates :duration_estimate, numericality: { greater_than: 0 }, allow_nil: true

  # Scopes
  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :by_type, ->(type) { where(training_type: type) }

  # Instance methods
  def archived?
    archived_at.present?
  end

  def archive!
    return if archived?
    update!(archived_at: Time.current)
  end

  def unarchive!
    return unless archived?
    update!(archived_at: nil)
  end
end
