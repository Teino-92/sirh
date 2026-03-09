# frozen_string_literal: true

class TrialWelcomeMailer < ApplicationMailer
  def welcome(employee, temp_password)
    @employee       = employee
    @temp_password  = temp_password
    @login_url      = new_employee_session_url
    @organization   = employee.organization

    mail(
      to:      employee.email,
      subject: "Bienvenue sur Izi-RH — vos accès sont prêts"
    )
  end
end
