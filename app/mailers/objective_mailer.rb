# frozen_string_literal: true

class ObjectiveMailer < ApplicationMailer
  # Notification à l'employé quand un objectif lui est affecté
  def assigned(objective)
    @objective = objective
    @employee  = objective.owner
    @manager   = objective.manager

    mail(
      to:      @employee.email,
      subject: "Nouvel objectif assigné : #{@objective.title}"
    )
  end
end
