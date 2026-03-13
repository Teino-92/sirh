# frozen_string_literal: true

class OneOnOneMailer < ApplicationMailer
  # Notification à l'employé quand un 1:1 est planifié
  def scheduled(one_on_one)
    @one_on_one = one_on_one
    @employee   = one_on_one.employee
    @manager    = one_on_one.manager

    mail(
      to:      @employee.email,
      subject: "Entretien 1:1 planifié avec #{@manager.full_name}"
    )
  end

  # Notification à l'employé quand un 1:1 est replanifié
  def rescheduled(one_on_one)
    @one_on_one = one_on_one
    @employee   = one_on_one.employee
    @manager    = one_on_one.manager

    mail(
      to:      @employee.email,
      subject: "Entretien 1:1 replanifié avec #{@manager.full_name}"
    )
  end

  # Notification à l'employé quand un 1:1 est annulé
  def cancelled(one_on_one)
    @one_on_one = one_on_one
    @employee   = one_on_one.employee
    @manager    = one_on_one.manager

    mail(
      to:      @employee.email,
      subject: "Entretien 1:1 annulé — #{@manager.full_name}"
    )
  end
end
