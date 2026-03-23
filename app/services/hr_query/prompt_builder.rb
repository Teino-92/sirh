# frozen_string_literal: true

module HrQuery
  class PromptBuilder
    CURRENT_YEAR = Date.current.year

    def self.system_prompt
      <<~PROMPT
        Tu es un convertisseur de requêtes RH en JSON. Tu ne fais QUE produire du JSON structuré.
        Tu ne donnes JAMAIS de conseils, d'analyses, d'explications ou de texte libre.
        Ta réponse est UNIQUEMENT un objet JSON valide, rien d'autre.
      PROMPT
    end

    def self.user_message(query)
      <<~MSG
        Convertis cette requête RH en JSON de filtres en suivant EXACTEMENT ce schéma.
        Ne réponds qu'avec le JSON, sans texte avant ou après.

        REQUÊTE: #{query}

        SCHÉMA OBLIGATOIRE (respecte tous les champs, mets null si non mentionné):
        {
          "version": "1",
          "employee": {
            "department": null,
            "role": null,
            "contract_type": null,
            "active_only": true,
            "cadre": null,
            "job_title_contains": null,
            "tenure_months_min": null,
            "tenure_months_max": null,
            "start_date_from": null,
            "start_date_to": null
          },
          "leave": {
            "leave_type": null,
            "days_used_min": null,
            "days_used_max": null,
            "period_year": null,
            "status": null
          },
          "evaluation": {
            "score_min": null,
            "score_max": null,
            "period_year": null,
            "status": null
          },
          "onboarding": {
            "status": null,
            "integration_score_min": null,
            "integration_score_max": null
          },
          "one_on_one": {
            "no_meeting_since_days": null,
            "total_completed_min": null,
            "period_days": null
          },
          "objective": {
            "status": null,
            "overdue": null,
            "priority": null
          },
          "time_tracking": {
            "late_checkins_min": null,
            "period_days": null
          },
          "training": {
            "status": null
          },
          "output": {
            "columns": ["name", "department"],
            "include_salary": false
          }
        }

        RÈGLES:
        - department: nom exact du département mentionné, ou null
        - role: "employee" | "manager" | "hr" | "admin" | null
        - contract_type: "CDI" | "CDD" | "Stage" | "Alternance" | "Interim" | null
        - cadre: true | false | null (true si "cadre" mentionné)
        - leave_type: "CP" | "RTT" | "Maladie" | "Maternite" | "Paternite" | "Sans_Solde" | "Anciennete" | null
        - days_used_min/max: nombre de jours (ex: "plus de 10 jours" → days_used_min: 10.5)
        - pour "cette année": period_year: #{CURRENT_YEAR}
        - include_salary: true UNIQUEMENT si salaire explicitement demandé
        - no_meeting_since_days: nombre de jours sans 1:1 (ex: "depuis 1 mois" → 30)
        - total_completed_min: nombre minimum de 1:1 complétés
        - one_on_one period_days: période en jours pour compter (ex: "ce trimestre" → 90, "ce mois" → 30)
        - objective status: "draft" | "in_progress" | "blocked" | "completed" | "cancelled" | null
        - objective priority: "low" | "medium" | "high" | null
        - overdue: true si deadline dépassée
        - late_checkins_min: nombre minimum de pointages en retard
        - training status: "assigned" | "in_progress" | "completed" | null
        - columns: liste pertinente parmi ["name","department","role","contract_type","job_title","start_date","tenure_months","leave_days_used","leave_type","evaluation_score","evaluation_status","onboarding_status","integration_score","salary","last_one_on_one_date","one_on_one_count","objective_status","objective_count","late_checkins_count","training_status"]
      MSG
    end
  end
end
