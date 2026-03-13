# frozen_string_literal: true

module BillingHelper
  PLAN_LABELS = {
    "manager_os"     => "Manager OS",
    "sirh_essential" => "SIRH Essentiel",
    "sirh_pro"       => "SIRH Pro"
  }.freeze

  def plan_label(plan)
    PLAN_LABELS.fetch(plan.to_s, plan.to_s.humanize)
  end
end
