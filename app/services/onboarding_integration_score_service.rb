# frozen_string_literal: true

# Computes an integration score (0–100) from four weighted components.
# If the manager review is absent, its weight is redistributed
# proportionally across the other three components.
class OnboardingIntegrationScoreService
    WEIGHTS = {
      task:        0.30,
      training:    0.25,
      one_on_one:  0.20,
      manager:     0.25
    }.freeze

    def initialize(onboarding)
      @onboarding = onboarding
    end

    def call
      tasks = @onboarding.onboarding_tasks.to_a

      task_rate       = rate(tasks.count { |t| t.status == 'completed' }, tasks.size)
      training_rate   = linked_rate(tasks, 'training',   'linked_training_assignment_id',
                                    TrainingAssignment, 'completed')
      oo_rate         = linked_rate(tasks, 'one_on_one', 'linked_one_on_one_id',
                                    OneOnOne, 'completed')
      manager_review  = @onboarding.onboarding_reviews
                                   .find_by(reviewer_type: 'manager', review_day: 30)
      manager_rate    = manager_review&.manager_integration_level&.then { |v| (v.to_f - 1) / 4 }

      weights = effective_weights(manager_rate)

      score = task_rate      * weights[:task] +
              training_rate  * weights[:training] +
              oo_rate        * weights[:one_on_one] +
              (manager_rate || 0.0) * weights[:manager]

      (score * 100).round
    end

    private

    def rate(done, total)
      return 0.0 if total.zero?

      done.to_f / total
    end

    def linked_rate(tasks, type, key, model, completed_status)
      ids = tasks.select { |t| t.task_type == type }
                 .filter_map { |t| t.metadata[key] }
      return 0.0 if ids.empty?

      done  = model.where(id: ids, status: completed_status).count
      rate(done, ids.size)
    end

    # When manager_rate is nil, redistribute its weight proportionally
    def effective_weights(manager_rate)
      return WEIGHTS if manager_rate

      extra = WEIGHTS[:manager]
      non_manager_sum = WEIGHTS[:task] + WEIGHTS[:training] + WEIGHTS[:one_on_one]

      WEIGHTS.merge(
        task:       WEIGHTS[:task]      + extra * (WEIGHTS[:task]      / non_manager_sum),
        training:   WEIGHTS[:training]  + extra * (WEIGHTS[:training]  / non_manager_sum),
        one_on_one: WEIGHTS[:one_on_one] + extra * (WEIGHTS[:one_on_one] / non_manager_sum),
        manager:    0.0
      )
    end
end
