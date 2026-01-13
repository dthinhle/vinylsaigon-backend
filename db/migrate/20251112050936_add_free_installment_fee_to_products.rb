class AddFreeInstallmentFeeToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :free_installment_fee, :boolean, default: false, null: false
  end
end
