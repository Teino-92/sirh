# frozen_string_literal: true

# Policy for the HR Query Engine (NL-to-Filters AI feature).
# The "record" is a symbol (:hr_query) — not a persisted resource.
# Only HR and admin users can run natural-language HR queries.
class HrQueryPolicy < ApplicationPolicy
  def show?
    user.hr_or_admin?
  end

  def create?
    user.hr_or_admin?
  end

  def export?
    user.hr_or_admin?
  end
end
