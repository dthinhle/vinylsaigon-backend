class CreatePaymentTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :payment_transactions, id: :uuid do |t|
      t.references :order, null: false, foreign_key: true, type: :uuid
      t.string :onepay_transaction_id
      t.decimal :amount
      t.string :status
      t.jsonb :raw_callback

      t.timestamps
    end
    add_index :payment_transactions, :onepay_transaction_id, unique: true
  end
end
