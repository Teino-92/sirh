# frozen_string_literal: true

class OrgMergeInvitation < ApplicationRecord
  # PAS d'acts_as_tenant — cross-tenant par nature
  belongs_to :target_organization, class_name: 'Organization'
  belongs_to :source_organization, class_name: 'Organization'
  belongs_to :invited_by, class_name: 'Employee'

  STATUSES = %w[pending accepted merging completed failed expired declined].freeze
  validates :status, inclusion: { in: STATUSES }
  validates :invited_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  validate :target_must_be_sirh
  validate :source_must_be_manager_os
  validate :no_active_invitation_for_source

  before_create :generate_token_and_expiry

  scope :pending, -> { where(status: 'pending') }
  scope :active,  -> { where(status: %w[pending accepted merging]) }

  def expired?
    status == 'pending' && expires_at < Time.current
  end

  def acceptable?
    status == 'pending' && !expired?
  end

  private

  def generate_token_and_expiry
    self.token      = SecureRandom.urlsafe_base64(32)
    self.expires_at = 7.days.from_now
  end

  def target_must_be_sirh
    return if target_organization&.sirh?
    errors.add(:target_organization, "doit être un plan SIRH")
  end

  def source_must_be_manager_os
    return if source_organization&.plan == 'manager_os'
    errors.add(:source_organization, "doit être un plan Manager OS")
  end

  def no_active_invitation_for_source
    return unless source_organization_id
    existing = OrgMergeInvitation
      .where(source_organization_id: source_organization_id)
      .where(status: %w[pending accepted merging])
      .where.not(id: id)
      .exists?
    errors.add(:base, "Une invitation active existe déjà pour cette organisation source") if existing
  end
end
