class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.string   :name, null: false
      t.string   :sku, null: false, index: { unique: true }
      t.text     :description
      t.string   :short_description, limit: 500
      t.decimal  :original_price, precision: 10, scale: 2, null: false
      t.decimal  :current_price, precision: 10, scale: 2
      t.string   :status, null: false, default: "active"
      t.string   :stock_status, null: false, default: "in_stock"
      t.integer  :stock_quantity, null: false, default: 0
      t.integer  :low_stock_threshold, null: false, default: 5
      t.decimal  :weight, precision: 8, scale: 2
      t.string   :meta_title, limit: 255
      t.string   :meta_description, limit: 500
      t.boolean  :featured, null: false, default: false
      t.integer  :sort_order, null: false, default: 0

      t.datetime :deleted_at, index: true
      t.timestamps
    end
  end
end
