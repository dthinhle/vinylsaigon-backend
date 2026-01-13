# frozen_string_literal: true

class Admin::MenusController < Admin::BaseController
  before_action :set_menu, only: [:show, :edit, :update, :destroy]

  def index
    @menus = MenuBar::Section.includes(items: { sub_items: :sub_items })
  end

  def show
  end

  def new
    @menu = MenuBar::Section.new
  end

  def create
    @menu = MenuBar::Section.new(menu_params)
    if @menu.save
      redirect_to admin_menu_path(@menu), notice: 'Menu was successfully created.'
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @menu.update(menu_params)
      redirect_to admin_menu_path(@menu), notice: 'Menu was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @menu.destroy!
    redirect_to admin_menus_path, notice: 'Menu was successfully deleted.'
  end

  private

  def set_menu
    @menu = MenuBar::Section.find(params[:id])
  end

  def menu_params
    params.require(:menu_bar_section).permit(:section_type)
  end
end
