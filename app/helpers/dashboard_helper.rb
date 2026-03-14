# frozen_string_literal: true

module DashboardHelper
  CARD_LABELS = {
    'leave_balances'       => 'Soldes de congés',
    'upcoming_leaves'      => 'Prochains congés',
    'personal_planning'    => 'Mon planning',
    'team_planning'        => 'Planning équipe',
    'pending_requests'     => 'Mes demandes',
    'pending_approvals'    => 'Approbations en attente',
    'my_performance'       => 'Ma performance',
    'team_performance'     => 'Performance équipe',
    'upcoming_one_on_ones' => 'Prochains 1:1',
    'absences_today'       => 'Absences du jour',
    'active_onboardings'   => 'Onboardings en cours',
    'trial_period_alerts'  => "Alertes période d'essai",
    'clock_inout'          => 'Pointage',
    'today_schedule'       => 'Horaire du jour',
    'quick_links'          => 'Accès rapides',
    'hr_referent'          => 'Référent RH',
  }.freeze

  CARD_MIN_H = {
    'personal_planning'    => 4,
    'team_planning'        => 4,
    'active_onboardings'   => 2,
    'upcoming_one_on_ones' => 3,
    'team_performance'     => 3,
    'quick_links'          => 3,
  }.freeze

  def card_label(card_id)
    CARD_LABELS.fetch(card_id, card_id.humanize)
  end

  def card_min_h(card_id)
    CARD_MIN_H.fetch(card_id, 2)
  end
end
