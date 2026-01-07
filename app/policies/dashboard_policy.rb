# frozen_string_literal: true

class DashboardPolicy < ApplicationPolicy
  # Dashboard is accessible to all authenticated employees
  def show?
    true
  end
end
