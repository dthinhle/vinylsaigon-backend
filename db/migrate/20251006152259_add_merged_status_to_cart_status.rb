class AddMergedStatusToCartStatus < ActiveRecord::Migration[8.0]
  def up
    execute <<-SQL
      ALTER TYPE cart_status ADD VALUE 'merged';
    SQL
  end

  def down
    # Note: PostgreSQL doesn't support removing enum values directly
    # You would need to recreate the enum type without 'merged' if you need to rollback
    raise ActiveRecord::IrreversibleMigration, "Cannot remove enum value 'merged' from cart_status"
  end
end
