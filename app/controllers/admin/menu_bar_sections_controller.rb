# frozen_string_literal: true

class Admin::MenuBarSectionsController < Admin::BaseController
  before_action :set_menu_bar_section, only: [:show, :edit, :update, :destroy]

  def index
    @menu_bar_sections = MenuBar::Section.includes(items: { sub_items: :sub_items }).all
  end

  def show
  end

  def new
    @menu_bar_section = MenuBar::Section.new
  end

  def create
    @menu_bar_section = MenuBar::Section.new(menu_bar_section_params)
    if @menu_bar_section.save
      redirect_to admin_menu_bar_section_path(@menu_bar_section), notice: 'Menu bar section was successfully created.'
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @menu_bar_section.update(menu_bar_section_params)
      redirect_to admin_menu_bar_section_path(@menu_bar_section), notice: 'Menu bar section was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @menu_bar_section.destroy!
    redirect_to admin_menu_bar_sections_path, notice: 'Menu bar section was successfully deleted.'
  end

  private

  def set_menu_bar_section
    @menu_bar_section = MenuBar::Section.includes(:items).find(params[:id])
  end

  def menu_bar_section_params
    params.require(:menu_bar_section).permit(:section_type)
  end
end
