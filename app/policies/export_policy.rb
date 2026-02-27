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

  def one_on_ones?
    user.manager?
  end

  def evaluations?
    user.manager?
  end

  def trainings?
    user.manager?
  end
end
