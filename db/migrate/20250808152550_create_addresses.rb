class CreateAddresses < ActiveRecord::Migration[8.0]
  def change
    create_table :addresses do |t|
      t.string :address, null: false
      t.string :ward
      t.string :district
      t.string :city, null: false
      t.string :map_url
      t.string :phone_numbers, array: true, default: []
      t.boolean :is_head_address, default: false
      t.references :addressable, polymorphic: true
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
