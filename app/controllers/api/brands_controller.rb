# frozen_string_literal: true

class Api::BrandsController < ApplicationController
  def index
    @brands = Brand
      .includes(:logo_attachment)
      .joins(:products)
      .where(products: { status: [:active, :discontinued] }).distinct
      .order(:name)
  end

  def show
    @brand = Brand.find_by!(slug: params[:slug])
  end
end
