# frozen_string_literal: true

class PagesController < ApplicationController
  skip_before_action :authenticate_employee!, raise: false
  layout 'marketing'

  def home
    @form_values ||= {}
    @errors      ||= []
  end

  def sirh; end

  def cgu; end
  def politique_de_confidentialite; end
  def mentions_legales; end
end
