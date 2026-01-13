class CreateSystemConfigs < ActiveRecord::Migration[8.0]
  def change
    create_table :system_configs do |t|
      t.string :name, null: false
      t.string :value, null: false

      t.timestamps
    end

    add_index :system_configs, :name, unique: true
  end
end
