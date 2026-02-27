# frozen_string_literal: true

# Creates all OnboardingTasks from the template and fires cross-domain
# integrations (Objective, TrainingAssignment, OneOnOne) in a single
# transaction. Idempotent: safe to call twice — returns early if tasks
# already exist.
class OnboardingInitializerService
    def initialize(onboarding)
      @onboarding = onboarding
    end

    def call
      return if @onboarding.onboarding_tasks.exists?

      ActiveRecord::Base.transaction do
        @onboarding.onboarding_template
                   .onboarding_template_tasks
                   .ordered
                   .each { |template_task| process(template_task) }
      end
    end

    private

    def process(template_task)
      due_date = @onboarding.start_date + template_task.due_day_offset.days

      task = @onboarding.onboarding_tasks.create!(
        organization:    @onboarding.organization,
        title:           template_task.title,
        description:     template_task.description,
        assigned_to_role: template_task.assigned_to_role,
        due_date:        due_date,
        task_type:       template_task.task_type,
        metadata:        {}
      )

      linked_metadata = create_linked_record(template_task, task, due_date)
      task.update!(metadata: linked_metadata) if linked_metadata.present?
    end

    def create_linked_record(template_task, _task, due_date)
      case template_task.task_type
      when 'objective_30', 'objective_60', 'objective_90'
        create_objective(template_task, due_date)
      when 'training'
        create_training_assignment(template_task, due_date)
      when 'one_on_one'
        create_one_on_one(template_task, due_date)
      end
    end

    def create_objective(template_task, due_date)
      title = template_task.metadata['title'].presence || template_task.title

      objective = Objective.create!(
        organization: @onboarding.organization,
        owner:        @onboarding.employee,
        manager:      @onboarding.manager,
        created_by:   @onboarding.manager,
        title:        title,
        description:  template_task.description,
        deadline:     due_date,
        status:       :in_progress,
        priority:     :medium
      )

      { 'linked_objective_id' => objective.id }
    end

    def create_training_assignment(template_task, due_date)
      training_id = template_task.metadata['training_id']
      return {} unless training_id

      training = Training.find_by(id: training_id,
                                  organization: @onboarding.organization)
      return {} unless training

      ta = TrainingAssignment.create!(
        training:    training,
        employee:    @onboarding.employee,
        assigned_by: @onboarding.manager,
        assigned_at: @onboarding.start_date,
        deadline:    due_date
      )

      { 'linked_training_assignment_id' => ta.id }
    end

    def create_one_on_one(template_task, due_date)
      title = template_task.metadata['title'].presence || template_task.title

      one_on_one = OneOnOne.create!(
        organization: @onboarding.organization,
        manager:      @onboarding.manager,
        employee:     @onboarding.employee,
        scheduled_at: due_date.to_datetime.change(hour: 10),
        agenda:       title,
        status:       :scheduled
      )

      { 'linked_one_on_one_id' => one_on_one.id }
    end
end
