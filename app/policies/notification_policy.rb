# frozen_string_literal: true

class NotificationPolicy < ApplicationPolicy
  def index?
    true # Everyone can see their notifications
  end

  def show?
    owner?
  end

  def mark_as_read?
    owner?
  end

  def mark_all_as_read?
    true # Can mark all own notifications as read
  end

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      # Users can only see their own notifications
      scope.where(employee_id: user.id)
    end
  end

  private

  def owner?
    record.employee_id == user.id
  end
end
