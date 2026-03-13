# frozen_string_literal: true

class TrainingAssignmentMailer < ApplicationMailer
  # Notification à l'employé quand une formation lui est affectée
  def assigned(training_assignment)
    @assignment  = training_assignment
    @employee    = training_assignment.employee
    @training    = training_assignment.training
    @assigned_by = training_assignment.assigned_by

    mail(
      to:      @employee.email,
      subject: "Formation assignée : #{@training.title}"
    )
  end
end
