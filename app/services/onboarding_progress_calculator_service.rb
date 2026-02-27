# frozen_string_literal: true

# Computes onboarding progress (0–100) from tasks, linked training
# assignments, 1:1s, and objectives. Loads onboarding_tasks once to
# avoid N+1 when extracting linked record IDs.
class OnboardingProgressCalculatorService
    def initialize(onboarding)
      @onboarding = onboarding
    end

    def call
      tasks = @onboarding.onboarding_tasks.to_a

      task_total = tasks.size
      task_done  = tasks.count { |t| t.status == 'completed' }

      training_ids = ids_from(tasks, 'training',     'linked_training_assignment_id')
      oo_ids       = ids_from(tasks, 'one_on_one',   'linked_one_on_one_id')
      obj_ids      = ids_from(tasks, %w[objective_30 objective_60 objective_90],
                                     'linked_objective_id')

      training_total = training_ids.size
      training_done  = training_ids.any? ? TrainingAssignment.where(id: training_ids, status: 'completed').count : 0

      oo_total = oo_ids.size
      oo_done  = oo_ids.any? ? OneOnOne.where(id: oo_ids, status: 'completed').count : 0

      obj_total = obj_ids.size
      obj_done  = obj_ids.any? ? Objective.where(id: obj_ids, status: 'completed').count : 0

      total = task_total + training_total + oo_total + obj_total
      done  = task_done  + training_done  + oo_done  + obj_done

      return 0 if total.zero?

      (done.to_f / total * 100).round
    end

    private

    def ids_from(tasks, types, key)
      type_array = Array(types)
      tasks.select { |t| type_array.include?(t.task_type) }
           .filter_map { |t| t.metadata[key] }
    end
end
