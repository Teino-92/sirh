# frozen_string_literal: true

# Policy for manager CSV export actions.
# The "record" is a symbol (:exports) — exports are not a persisted resource.
class ExportPolicy < ApplicationPolicy
  def index?
    user.manager?
  end

  def time_entries?
    user.manager?
  end

  def absences?
    user.manager?
  end

  def search?
    user.manager?
  end

  def search_export?
    user.manager?
  end
end
