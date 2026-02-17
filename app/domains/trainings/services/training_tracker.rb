module Trainings
  module Services
    class TrainingTracker
      def initialize(organization)
        @organization = organization
      end

      # Identify employees without completed training in the last N months
      def employees_without_training(months: 6)
        ActsAsTenant.with_tenant(@organization) do
          cutoff = months.months.ago

          trained_employee_ids = TrainingAssignment
                                   .where(status: :completed)
                                   .where('completed_at >= ?', cutoff)
                                   .distinct
                                   .pluck(:employee_id)

          @organization.employees.active.where.not(id: trained_employee_ids)
        end
      end

      # Assign training to multiple employees atomically
      def bulk_assign(training:, employee_ids:, assigned_by:, deadline: nil)
        ActsAsTenant.with_tenant(@organization) do
          assignments = []

          ActiveRecord::Base.transaction do
            employee_ids.each do |employee_id|
              assignments << TrainingAssignment.create!(
                training: training,
                employee_id: employee_id,
                assigned_by: assigned_by,
                deadline: deadline,
                assigned_at: Date.current
              )
            end
          end

          assignments
        end
      end

      # Summary of training completion for an organization
      def completion_summary(year: Date.current.year)
        ActsAsTenant.with_tenant(@organization) do
          total_employees = @organization.employees.active.count
          trained_this_year = TrainingAssignment
                                .where(status: :completed)
                                .where('EXTRACT(YEAR FROM completed_at) = ?', year)
                                .distinct
                                .count(:employee_id)

          {
            total: total_employees,
            trained: trained_this_year,
            untrained: total_employees - trained_this_year,
            rate: total_employees > 0 ? (trained_this_year.to_f / total_employees * 100).round(1) : 0
          }
        end
      end
    end
  end
end
