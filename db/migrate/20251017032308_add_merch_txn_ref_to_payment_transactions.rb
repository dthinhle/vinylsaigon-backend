class AddMerchTxnRefToPaymentTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :payment_transactions, :merch_txn_ref, :string
    add_index :payment_transactions, :merch_txn_ref
  end
end
