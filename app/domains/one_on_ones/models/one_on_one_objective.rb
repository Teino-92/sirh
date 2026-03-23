class OneOnOneObjective < ApplicationRecord
  belongs_to :one_on_one
  belongs_to :objective

  validate :same_organization

  private

  def same_organization
    return unless one_on_one.present? && objective.present?
    unless one_on_one.organization_id == objective.organization_id
      errors.add(:base, "Le 1:1 et l'objectif doivent appartenir à la même organisation")
    end
  end
end
