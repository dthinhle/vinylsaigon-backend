class Admin::MenuBarItemsController < Admin::BaseController
  # PATCH /admin/menu_bar_items/sort
  # Expects params[:items] (array of {id, parent_id, position})
  def sort
    items = params[:items].presence || params.dig(:menu_bar_item, :items).presence

    service = MenuBar::SortService.new(items: items)

    begin
      result = service.call

      if result[:errors].any?
        Rails.logger.warn("[MenuBarItemsController#sort] Errors: #{result[:errors].inspect}")
        render json: { updated: result[:updated_count], errors: result[:errors] }, status: :unprocessable_entity
      else
        render json: result[:items]
      end
    rescue MenuBar::SortService::ValidationError => e
      Rails.logger.warn("[MenuBarItemsController#sort] Validation error: #{e.message} params=#{params.inspect}")
      render json: { error: e.message }, status: :unprocessable_entity
    rescue => e
      Rails.logger.error("[MenuBarItemsController#sort] Unexpected error: #{e.message}")
      render json: { error: 'Internal server error' }, status: :internal_server_error
    end
  end

  # POST /admin/menu_bar_items
  # Create a top-level or nested menu item. For top-level, parent_id should be nil.
  def create
    @menu_bar_item = MenuBar::Item.new(menu_bar_item_params)

    # Ensure top-level when parent_id is blank
    if params.dig(:menu_bar_item, :parent_id).blank?
      @menu_bar_item.parent_id = nil
    end

    # Set a sensible default position for top-level items if not provided
    if @menu_bar_item.position.blank?
      last_pos = MenuBar::Item.where(menu_bar_section_id: @menu_bar_item.menu_bar_section_id, parent_id: @menu_bar_item.parent_id).maximum(:position) || 0
      @menu_bar_item.position = last_pos + 1
    end

    if @menu_bar_item.save
      @menu_item = @menu_bar_item
      respond_to do |format|
        format.html { redirect_to admin_menu_bar_item_path(@menu_bar_item), notice: 'Menu bar item was successfully created.' }
        format.turbo_stream
      end
    else
      @menu_item = @menu_bar_item
      respond_to do |format|
        # Return 422 with rendered form so clients can surface validation errors
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream { render :create, status: :unprocessable_entity }
      end
    end
  end

  def show
    @menu_bar_item = MenuBar::Item.find(params[:id])
    respond_to do |format|
      if params[:modal].present?
        # Return a turbo-stream response that replaces the global modal element
        format.html { render :show_modal }
        format.turbo_stream { render :show_modal }
      else
        format.html { render partial: 'admin/menus/menu_item', locals: { item: @menu_bar_item, depth: 0 } }
        format.turbo_stream
      end
    end
  end

  def update
    @menu_bar_item = MenuBar::Item.find(params[:id])
    if @menu_bar_item.update(menu_bar_item_params)
      # If frontend signaled images to remove, purge them (submitted as top-level images_to_remove[])
      if params[:images_to_remove].present?
        Array(params[:images_to_remove]).each do |remove_id|
          # remove_id can be a MenuBar::Item id (legacy) or an ActiveStorage::Blob id (preferred)
          if remove_id.to_s.match?(/\A\d+\z/)
            # First try treating as blob id
            blob = ActiveStorage::Blob.find_by(id: remove_id)
            if blob
              # Purge attachment records that reference this blob (if any)
              ActiveStorage::Attachment.where(blob_id: blob.id).find_each do |att|
                att.purge_later
              end
              next
            end

            # Fallback: treat as MenuBar::Item id
            item = MenuBar::Item.find_by(id: remove_id)
            if item && item.image.attached?
              item.image.purge_later
            end
          end
        end
      end

      # expose a simple name the view expects
      @menu_item = @menu_bar_item
      respond_to do |format|
        format.html { redirect_to admin_menu_bar_item_path(@menu_bar_item), notice: 'Menu bar item was successfully updated.' }
        format.turbo_stream { render :update, status: :ok }
      end
    else
      @menu_item = @menu_bar_item
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream { render :update, status: :unprocessable_entity }
      end
    end
  end

  def move_subtree
    # Validate required parameters
    moved_item_id = params[:moved_item_id].presence
    dest_parent_id = params[:dest_parent_id].presence
    dest_position = params[:dest_position].presence

    unless moved_item_id.present? && dest_position.present?
      Rails.logger.warn("[MenuBarItemsController#move_subtree] Missing required parameters: moved_item_id=#{moved_item_id}, dest_position=#{dest_position}")
      render json: { error: 'Missing required parameters: moved_item_id and dest_position' }, status: :bad_request and return
    end

    # Validate moved_item_id is a valid integer
    unless moved_item_id.to_s.match?(/\A\d+\z/)
      Rails.logger.warn("[MenuBarItemsController#move_subtree] Invalid moved_item_id: #{moved_item_id}")
      render json: { error: 'moved_item_id must be a valid integer' }, status: :bad_request and return
    end

    # Validate dest_position is a valid integer
    unless dest_position.to_s.match?(/\A\d+\z/)
      Rails.logger.warn("[MenuBarItemsController#move_subtree] Invalid dest_position: #{dest_position}")
      render json: { error: 'dest_position must be a valid integer' }, status: :bad_request and return
    end

    # Validate dest_parent_id is either nil or a valid integer
    if dest_parent_id.present? && !dest_parent_id.to_s.match?(/\A\d+\z/)
      Rails.logger.warn("[MenuBarItemsController#move_subtree] Invalid dest_parent_id: #{dest_parent_id}")
      render json: { error: 'dest_parent_id must be a valid integer or null' }, status: :bad_request and return
    end

    # Call the service to perform the move
    service = MenuBar::MoveSubtreeService.new(
      moved_item_id: moved_item_id,
      dest_parent_id: dest_parent_id,
      dest_position: dest_position
    )

    begin
      result = service.call

      if result[:status] == :success
        # Return updated subtree information
        updated_items = MenuBar::Item.where(id: result[:subtree_ids])
                                     .order(:parent_id, :position)
                                     .pluck(:id, :parent_id, :position)

        render json: {
          success: true,
          updated_items: updated_items.map { |id, parent_id, position|
            { id: id, parent_id: parent_id, position: position }
          }
        }
      else
        # Handle background job case
        render json: result, status: :accepted
      end
    rescue MenuBar::MoveSubtreeService::ValidationError => e
      Rails.logger.warn("[MenuBarItemsController#move_subtree] Validation error: #{e.message}")
      render json: { error: e.message }, status: :unprocessable_entity
    rescue => e
      Rails.logger.error("[MenuBarItemsController#move_subtree] Unexpected error: #{e.message}")
      render json: { error: 'Internal server error' }, status: :internal_server_error
    end
  end

  # DELETE /admin/menu_bar_items/:id
  # Deletes the item and all its descendant sub-items. Returns turbo_stream/html.
  def destroy
    @menu_bar_item = MenuBar::Item.find(params[:id])

    # Collect subtree ids before destruction for turbo-stream response
    @deleted_ids = collect_subtree_ids(@menu_bar_item)

    # Let ActiveRecord handle cascading deletes via dependent: :destroy
    @menu_bar_item.destroy

    respond_to do |format|
      format.html { redirect_back fallback_location: admin_menus_path, notice: 'Menu item and its sub-items were successfully deleted.' }
      format.turbo_stream
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_back fallback_location: admin_menus_path, alert: 'Menu item not found.' }
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          'flash',
          "<div class='notice notice--alert'>Menu item not found.</div>".html_safe
        )
      end
    end
  rescue => e
    Rails.logger.error("[MenuBarItemsController#destroy] Unexpected error: #{e.message}")
    respond_to do |format|
      format.html { redirect_back fallback_location: admin_menus_path, alert: 'Failed to delete menu item.' }
      format.turbo_stream { render turbo_stream: turbo_stream.replace('flash', ''), status: :internal_server_error }
    end
  end

  private

  # Collect all subtree IDs (breadth-first) for turbo-stream response
  def collect_subtree_ids(item)
    subtree_ids = []
    queue = [item.id]
    while queue.any?
      subtree_ids.concat(queue)
      children = MenuBar::Item.where(parent_id: queue).pluck(:id)
      queue = children
    end
    subtree_ids.uniq
  end

  # Recursively permit sub_items_attributes for nested editing
  def menu_bar_item_params
    params.require(:menu_bar_item).permit(
      :label, :link, :item_type, :position, :menu_bar_section_id, :parent_id, :image,
      sub_items_attributes: permitted_sub_items_attributes
    )
  end

  def permitted_sub_items_attributes
    [
      :id, :label, :link, :item_type, :position, :menu_bar_section_id, :parent_id, :image, :_destroy,
      { sub_items_attributes: [
        :id, :label, :link, :item_type, :position, :menu_bar_section_id, :parent_id, :image, :_destroy,
      ] },
    ]
  end
end
