class ActionItemTracker
  def initialize(employee)
    @employee = employee
  end

  def my_action_items(status: nil)
    items = ActionItem.joins(:one_on_one)
                      .where(one_on_ones: { employee: @employee })
                      .or(ActionItem.where(responsible: @employee))

    items = items.where(status: status) if status
    items.order(deadline: :asc)
  end

  def overdue_items
    my_action_items.overdue
  end

  def link_objective_as_action_item(one_on_one:, objective:, deadline:)
    ActionItem.create!(
      one_on_one: one_on_one,
      organization: one_on_one.organization,
      responsible: objective.owner,
      objective: objective,
      description: "Follow up on: #{objective.title}",
      deadline: deadline,
      status: :pending,
      responsible_type: :employee
    )
  end
end
