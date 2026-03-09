# frozen_string_literal: true

class PayrollPeriodPolicy < ApplicationPolicy
  include PlanGated

  def index?   = sirh_plan? && user.hr_or_admin?
  def create?  = sirh_plan? && user.hr_or_admin?
  def destroy? = sirh_plan? && user.hr_or_admin?
end
