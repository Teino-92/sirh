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

  private

  def profile_params
    params.require(:employee).permit(:phone, :address, :avatar)
  end
end
