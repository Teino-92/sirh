# frozen_string_literal: true

class Subscription < ApplicationRecord
  belongs_to :organization
  # NOTE: acts_as_tenant intentionnellement absent ici.
  # Les webhook handlers tournent sans tenant Devise (ActionController::Base),
  # donc ActsAsTenant.current_tenant est nil. On fait des lookups globaux par
  # stripe_subscription_id et on revalide l'appartenance org explicitement.
  # Le scoping multi-tenant est garanti par la FK organization_id + Pundit dans BillingsController.

  PLANS = %w[manager_os sirh_essential sirh_pro].freeze

  STATUSES = %w[
    incomplete
    trialing
    active
    past_due
    canceled
  ].freeze

  validates :plan,               inclusion: { in: PLANS }
  validates :status,             inclusion: { in: STATUSES }
  validates :stripe_customer_id, presence: true

  validate :stripe_subscription_id_format, if: -> { stripe_subscription_id.present? }
  validate :stripe_checkout_session_id_format, if: -> { stripe_checkout_session_id.present? }

  scope :active,   -> { where(status: %w[active trialing]) }
  scope :past_due, -> { where(status: "past_due") }

  def active?
    status.in?(%w[active trialing])
  end

  def canceled?
    status == "canceled"
  end

  def past_due?
    status == "past_due"
  end

  def incomplete?
    status == "incomplete"
  end

  def can_cancel?
    return true if commitment_end_at.blank?
    Time.current >= commitment_end_at
  end

  def committed?
    commitment_end_at.present? && Time.current < commitment_end_at
  end

  def commitment_months_remaining
    return 0 unless committed?
    ((commitment_end_at - Time.current) / 1.month).ceil
  end

  def manager_os?
    plan == "manager_os"
  end

  def sirh_essential?
    plan == "sirh_essential"
  end

  def sirh_pro?
    plan == "sirh_pro"
  end

  private

  def stripe_subscription_id_format
    errors.add(:stripe_subscription_id, "format invalide") unless stripe_subscription_id.match?(/\Asub_/)
  end

  def stripe_checkout_session_id_format
    errors.add(:stripe_checkout_session_id, "format invalide") unless stripe_checkout_session_id.match?(/\Acs_/)
  end
end
