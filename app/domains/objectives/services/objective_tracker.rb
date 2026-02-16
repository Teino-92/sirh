module Objectives
  module Services
    class ObjectiveTracker
      def initialize(organization)
        @organization = organization
        ActsAsTenant.current_tenant = organization
      end

      def team_progress_summary(manager)
        objectives = Objective.for_manager(manager).active

        {
          total: objectives.count,
          in_progress: objectives.in_progress.count,
          blocked: objectives.blocked.count,
          overdue: objectives.overdue.count,
          due_soon: objectives.upcoming.count
        }
      end

      def bulk_complete(objective_ids, completed_by:)
        objectives = Objective.where(id: objective_ids, manager: completed_by)

        ActiveRecord::Base.transaction do
          objectives.each(&:complete!)
        end

        objectives.count
      end
    end
  end
end
