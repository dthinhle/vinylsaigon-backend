class ChangeShortDescriptionToRichText < ActiveRecord::Migration[8.1]
  def change
    remove_column :products, :short_description, :string, limit: 500
    add_column :products, :short_description, :jsonb, default: {}, null: false
    add_column :products, :warranty_months, :integer

    change_column_default :products, :free_installment_fee, from: false, to: true
  end
end
