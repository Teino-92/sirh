# frozen_string_literal: true

class ProfileController < ApplicationController
  before_action :authenticate_employee!

  def show
    @employee = current_employee
    authorize @employee
  end

  def edit
    @employee = current_employee
    authorize @employee
  end

  def update
    @employee = current_employee
    authorize @employee

    if @employee.update(profile_params)
      redirect_to profile_path, notice: 'Profil mis à jour avec succès.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def dashboard_layout
    @employee = current_employee
    authorize @employee, :update?

    raw    = params.require(:dashboard_layout)
    hidden = Array(raw[:hidden]).map(&:to_s)

    # GridStack format: grid is an array of { id, x, y, w, h }
    grid = Array(raw[:grid]).filter_map do |item|
      id = item[:id].to_s
      next unless @employee.dashboard_card_permitted?(id)
      { 'id' => id,
        'x'  => item[:x].to_i,
        'y'  => item[:y].to_i,
        'w'  => item[:w].to_i.clamp(1, 12),
        'h'  => item[:h].to_i.clamp(1, 20) }
    end

    layout = {
      'grid'   => grid,
      'hidden' => hidden.select { |c| @employee.dashboard_card_permitted?(c) }
    }

    @employee.dashboard_layout = layout

    if @employee.save
      render json: { status: 'ok', message: 'Préférences sauvegardées' }
    else
      render json: { status: 'error' }, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:employee).permit(:phone, :address, :avatar)
  end
end
