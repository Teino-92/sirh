# frozen_string_literal: true

class PayrollPeriodPolicy < ApplicationPolicy
  def index?   = user.hr_or_admin?
  def create?  = user.hr_or_admin?
  def destroy? = user.hr_or_admin?
end
