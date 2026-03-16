# frozen_string_literal: true

module Admin
  class BusinessRulesController < BaseController
    before_action :set_rule, only: %i[show edit update destroy toggle]

    def index
      @rules = policy_scope(BusinessRule)
                 .order(:priority, :name)
      authorize BusinessRule
    end

    def show
      authorize @rule
      @executions = @rule.rule_executions.order(created_at: :desc).limit(20)
    end

    def new
      @rule = BusinessRule.new(
        priority: 10,
        active: true,
        conditions: [],
        actions: []
      )
      authorize @rule
    end

    def create
      @rule = BusinessRule.new(rule_params)
      @rule.organization = current_organization
      authorize @rule

      if @rule.save
        redirect_to admin_business_rules_path, notice: "Règle créée avec succès."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @rule
    end

    def update
      authorize @rule

      if @rule.update(rule_params)
        redirect_to admin_business_rules_path, notice: "Règle mise à jour."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @rule
      @rule.destroy!
      redirect_to admin_business_rules_path, notice: "Règle supprimée."
    end

    def toggle
      authorize @rule, :toggle?
      @rule.update!(active: !@rule.active)
      redirect_to admin_business_rules_path,
        notice: "Règle #{@rule.active? ? 'activée' : 'désactivée'}."
    end

    private

    def set_rule
      @rule = current_organization.business_rules.find(params[:id])
    end

    def rule_params
      parsed = params.require(:business_rule).permit(
        :name, :trigger, :priority, :active, :description
      )

      # Conditions & actions arrivent en JSON string depuis le builder Stimulus
      raw = params.require(:business_rule)

      if raw[:conditions_json].present?
        parsed[:conditions] = JSON.parse(raw[:conditions_json])
      end

      if raw[:actions_json].present?
        parsed[:actions] = JSON.parse(raw[:actions_json])
      end

      parsed
    rescue JSON::ParserError => e
      @rule ||= BusinessRule.new
      @rule.errors.add(:base, "JSON invalide : #{e.message}")
      raise ActiveRecord::RecordInvalid.new(@rule)
    end
  end
end
