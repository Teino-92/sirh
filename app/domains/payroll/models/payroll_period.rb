# frozen_string_literal: true

class PayrollPeriod < ApplicationRecord
  has_paper_trail on: %i[create destroy],
                  meta: { organization_id: :organization_id }

  acts_as_tenant :organization

  belongs_to :organization
  belongs_to :locked_by, class_name: 'Employee'

  validates :period,    presence: true
  validates :locked_at, presence: true
  validates :locked_by, presence: true
  validates :period, uniqueness: { scope: :organization_id,
                                   message: "est déjà clôturée pour cette organisation" }

  before_validation :normalize_period

  scope :for_period, ->(p) { where(period: p.to_date.beginning_of_month) }
  scope :recent, -> { order(period: :desc) }

  # True if the given date's month is locked for the given organization.
  # Single indexed lookup — O(log n).
  def self.locked?(organization_id, date)
    exists?(organization_id: organization_id, period: date.to_date.beginning_of_month)
  end

  private

  def normalize_period
    self.period = period.to_date.beginning_of_month if period.present?
  end
end
