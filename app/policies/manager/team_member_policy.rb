# frozen_string_literal: true

module Manager
  class TeamMemberPolicy < ApplicationPolicy
    def show?
      manager_owns_record?
    end

    def new?
      user.manager?
    end

    def create?
      user.manager?
    end

    def edit?
      manager_owns_record?
    end

    def update?
      manager_owns_record?
    end

    def destroy?
      manager_owns_record?
    end

    private

    def manager_owns_record?
      user.manager? && record.manager_id == user.id
    end
  end
end
