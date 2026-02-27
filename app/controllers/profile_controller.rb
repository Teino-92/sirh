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

    raw = params.require(:dashboard_layout)

    order  = Array(raw[:order]).map(&:to_s)
    hidden = Array(raw[:hidden]).map(&:to_s)
    sizes  = (raw[:sizes].presence || {}).to_unsafe_h.transform_values(&:to_s)

    # Server-side: strip role-forbidden cards
    permitted = order.select { |c| @employee.dashboard_card_permitted?(c) }
    layout = {
      'order'  => permitted,
      'hidden' => hidden.select { |c| @employee.dashboard_card_permitted?(c) },
      'sizes'  => sizes.slice(*permitted)
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
