module Api
  class MenuBarController < ApplicationController
    def update
      result = MenuBar::UpsertMenuService.new(menu_params).perform
      if result[:status] == :error
        render json: { error: result[:error] }, status: :unprocessable_entity
      else
        @sections = result[:sections]
      end
    end

    private

    def menu_params
      params.require(:menu).permit(
        left_section: permitted_item_params,
        main_section: permitted_item_params,
        right_section: [:image_src, :link, :label]
      )
    end

    def permitted_item_params
      [
        :type,
        :label,
        :link,
        sub_items: [
          :type,
          :label,
          :link,
          sub_items: [
            :type,
            :label,
            :link,
          ],
        ],
      ]
    end
  end
end
