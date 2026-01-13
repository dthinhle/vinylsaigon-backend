module MenuBar
  class MoveSubtreeService
    # Service for moving menu item subtrees with validation and reindexing
    # Handles both small synchronous moves and large background moves

    def initialize(moved_item_id:, dest_parent_id:, dest_position:, section_id: nil)
      @moved_item_id = moved_item_id.to_i
      @dest_parent_id = dest_parent_id&.to_i
      @dest_position = dest_position.to_i
      @section_id = section_id&.to_i
    end

    def call
      validate_inputs
      validate_move_not_into_descendant
      compute_subtree_ids

      perform_synchronous_move
    end

    private

    attr_reader :moved_item_id, :dest_parent_id, :dest_position, :section_id

    BATCH_THRESHOLD = 500 # Configurable threshold for background processing

    def validate_inputs
      # Validate moved item exists
      @moved_item = MenuBar::Item.find_by(id: moved_item_id)
      raise ValidationError, 'Moved item not found' unless @moved_item

      # Validate destination parent exists (if specified)
      if dest_parent_id.present?
        @dest_parent = MenuBar::Item.find_by(id: dest_parent_id)
        raise ValidationError, 'Destination parent not found' unless @dest_parent

        # Prevent assigning parent to itself
        if dest_parent_id == moved_item_id
          raise ValidationError, 'Destination parent cannot be the item itself'
        end
      end

      # Validate position is positive
      raise ValidationError, 'Position must be positive' unless dest_position > 0

      # Set section_id from moved item if not provided
      @section_id ||= @moved_item.menu_bar_section_id
    end

    def validate_move_not_into_descendant
      return unless dest_parent_id.present?

      # Use recursive CTE to check if destination parent is a descendant of moved item
      sql = <<-SQL
        WITH RECURSIVE descendants AS (
          SELECT id, parent_id FROM menu_bar_items WHERE id = $1
          UNION ALL
          SELECT mbi.id, mbi.parent_id
          FROM menu_bar_items mbi
          INNER JOIN descendants d ON d.id = mbi.parent_id
        )
        SELECT 1 FROM descendants WHERE id = $2 LIMIT 1
      SQL

      result = ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.sanitize_sql_array([sql, moved_item_id, dest_parent_id])
      )

      raise ValidationError, 'Cannot move item into its own descendant' if result.any?
    end

    def compute_subtree_ids
      # Use recursive CTE to get all descendant IDs including the moved item
      sql = <<-SQL
        WITH RECURSIVE subtree AS (
          SELECT id FROM menu_bar_items WHERE id = $1
          UNION ALL
          SELECT mbi.id
          FROM menu_bar_items mbi
          INNER JOIN subtree s ON s.id = mbi.parent_id
        )
        SELECT id FROM subtree ORDER BY id
      SQL

      result = ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.sanitize_sql_array([sql, moved_item_id])
      )

      @subtree_ids = result.map { |row| row['id'].to_i }
    end

    def subtree_size
      @subtree_ids.size
    end

    def perform_synchronous_move
      ActiveRecord::Base.transaction do
        # Lock the section to prevent concurrent modifications
        lock_section

        # Remove subtree from current position
        remove_from_current_position

        # Insert subtree at new position
        insert_at_new_position
      end

      { status: :success, subtree_ids: @subtree_ids }
    end

    def lock_section
      # Use advisory lock per section to serialize operations
      ActiveRecord::Base.connection.execute(
        "SELECT pg_advisory_xact_lock(#{section_id})"
      )
    end

    def remove_from_current_position
      # Mark subtree items as temporarily removed for reindexing
      MenuBar::Item.where(id: @subtree_ids).update_all(position: -1)
    end

    def insert_at_new_position
      # Update positions and parent_id for subtree items using safe ActiveRecord methods
      @subtree_ids.each_with_index do |id, index|
        if id == moved_item_id
          MenuBar::Item.where(id: id).update_all(position: dest_position + index, parent_id: dest_parent_id)
        else
          MenuBar::Item.where(id: id).update_all(position: dest_position + index)
        end
      end
    end

    class ValidationError < StandardError; end
  end
end
