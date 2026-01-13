# frozen_string_literal: true

require 'securerandom'

puts 'Seeding payment transactions...'

# Idempotent seed for payment transactions
unless Order.exists?
  puts "⚠ Skipping payment transaction seeds - need orders first."
  return
end

payment_transactions_created = 0

# --- Seeding Logic ---

ActiveRecord::Base.transaction do
 puts "\n--- Seeding Payment Transactions ---"

  orders = Order.includes(:user).limit(20).to_a

  # Define realistic response codes and their meanings based on OnePay documentation (Onepay-2025.pdf)
  response_codes = {
    success: '0',                          # Approved / Successful Transaction
    pending: ['300', '100'],               # 300: pending, 100: in progress / not paid
    failed: %w[
      1 2 3 4 5 6 7 8 9 10 11 12 13 14
      21 22 23 24 25 26 98 99 253
      B D F U Z
    ]                                       # Various failure and cancel codes (numeric and letter codes)
  }

  # Friendly messages for common failure codes (used for seeded vpc_Message)
  failure_messages = {
    '99' => 'User Cancel',
    'F'  => '3D Secure Fail',
    'U'  => 'Card Security Code Failed',
    'Z'  => 'Cannot process card',
    '98' => 'Authentication cancelled',
    '253'=> 'Expired session'
  }

 # Create payment transactions for some orders
 orders.each_with_index do |order, index|
    # Skip if order already has a payment transaction
    next if PaymentTransaction.exists?(order: order)

    # Decide if this should be an installment payment (30% chance for orders with free installment products, 15% otherwise)
    is_installment = order.has_free_installment_product? ? (rand < 0.3) : (rand < 0.15)

    # Randomly decide the transaction status
    status_category = [:success, :pending, :failed].sample
    case status_category
    when :success
      status = response_codes[:success]
      amount = order.total_vnd # Use the order's total as the payment amount
    when :pending
      status = response_codes[:pending].sample
      amount = order.total_vnd
    when :failed
      status = response_codes[:failed].sample
      amount = order.total_vnd
    end

    # Create a realistic OnePay transaction ID
    onepay_transaction_id = "OP#{Time.current.to_i}#{rand(1000..9999)}"

    # Create a merchant transaction reference (typically includes order number)
    merch_txn_ref = "#{order.order_number}--#{Time.current.to_i}"

    # Generate installment details if applicable
    installment_months = nil
    installment_bank = nil
    installment_fee_amount = nil

    if is_installment && status_category == :success
      installment_months = [3, 6, 9, 12].sample
      installment_bank = ['VISA', 'MASTERCARD', 'JCB', 'AMEX'].sample
      # Fee is typically 1-3% per month of the total amount
      monthly_rate = rand(1.0..3.0)
      installment_fee_amount = (amount * monthly_rate * installment_months / 100).round(-3) # Round to nearest 1000

      # Update order with installment metadata
      order.update!(
        metadata: (order.metadata || {}).merge(
          'payment_method' => 'installment',
          'installment_bank' => installment_bank,
          'installment_months' => installment_months,
          'installment_fee_amount' => installment_fee_amount
        )
      )
    end

    # Create realistic raw callback data based on status
    raw_callback = case status_category
    when :success
                     callback = {
                       "vpc_TxnResponseCode" => status,
                       "vpc_Amount" => (amount * 100).to_i,  # Amount in minor units
                       "vpc_Message" => "Approved",
                       "vpc_TransactionNo" => rand(1000000..9999999),
                       "vpc_OrderInfo" => order.order_number,
                       "vpc_Merchant" => "3KSHOP",
                       "vpc_CurrencyCode" => "VND",
                       "vpc_Version" => "2.1",
                       "vpc_Command" => "pay",
                       "vpc_Locale" => "en",
                       "vpc_MerchTxnRef" => merch_txn_ref,
                       "vpc_AuthorizeId" => "AUTH#{rand(100..99999)}",
                       "vpc_Card" => installment_bank || "VISA",
                       "vpc_3DSXID" => SecureRandom.hex(16),
                       "vpc_CardType" => "C",
                       "vpc_AcqResponseCode" => "00",
                       "vpc_CreatedAt" => Time.current.iso8601
                     }
                     # Add installment-specific fields if applicable
                     if is_installment
                       callback.merge!({
                         "vpc_ItaBankCode" => installment_bank,
                         "vpc_ItaFeeAmount" => (installment_fee_amount * 100).to_i,  # In minor units
                         "vpc_ItaMonths" => installment_months.to_s
                       })
                     end
                     callback
    when :pending
                     {
                       "vpc_TxnResponseCode" => status,
                       "vpc_Amount" => (amount * 100).to_i,
                       "vpc_Message" => "Pending",
                       "vpc_TransactionNo" => rand(1000000..99999),
                       "vpc_OrderInfo" => order.order_number,
                       "vpc_Merchant" => "3KSHOP",
                       "vpc_CurrencyCode" => "VND",
                       "vpc_Version" => "2.1",
                       "vpc_Command" => "pay",
                       "vpc_Locale" => "en",
                       "vpc_MerchTxnRef" => merch_txn_ref,
                       "vpc_CreatedAt" => Time.current.iso8601,
                       "vpc_AdditionalInfo" => "Transaction is still being processed"
                     }
    when :failed
                      {
                        "vpc_TxnResponseCode" => status,
                        "vpc_Amount" => (amount * 100).to_i,
                        "vpc_Message" => (failure_messages[status] || "Declined"),
                        "vpc_OrderInfo" => order.order_number,
                        "vpc_Merchant" => "3KSHOP",
                        "vpc_CurrencyCode" => "VND",
                        "vpc_Version" => "2.1",
                        "vpc_Command" => "pay",
                        "vpc_Locale" => "en",
                        "vpc_MerchTxnRef" => merch_txn_ref,
                        "vpc_CreatedAt" => Time.current.iso8601,
                        "vpc_ErrorMessage" => (failure_messages[status] || "Insufficient funds")
                      }
    end

    # Create the payment transaction
    PaymentTransaction.create!(
      order: order,
      onepay_transaction_id: onepay_transaction_id,
      amount: amount,
      status: status,
      merch_txn_ref: merch_txn_ref,
      raw_callback: raw_callback
    )

    # Update the order's payment status based on the transaction status
    case status_category
    when :success
      order.update!(payment_status: 'paid', status: 'paid')
    when :failed
      order.update!(payment_status: 'failed', status: 'failed')
    when :pending
      order.update!(payment_status: 'pending')
    end

    installment_info = is_installment ? " (Installment: #{installment_bank} #{installment_months}m, Fee: #{installment_fee_amount} VND)" : ""
    puts "✓ Payment Transaction ##{index + 1}: Order #{order.order_number}, Status: #{status}, Amount: #{amount} VND#{installment_info}"
    payment_transactions_created += 1
  end
end

  # Ensure we have at least a small number of installment transactions for local/dev testing
  begin
    minimum_installments = 3
    current_installments = PaymentTransaction.installment_only.count

    if current_installments < minimum_installments
      needed = minimum_installments - current_installments
      puts "\n--- Creating "+needed.to_s+" additional installment transactions (idempotent) ---"

      # Prefer orders that contain free_installment_fee products and don't already have a txn
      candidates = Order.joins(order_items: :product)
                        .where(products: { free_installment_fee: true })
                        .where.not(id: PaymentTransaction.select(:order_id))
                        .distinct
                        .limit(needed)
                        .to_a

      # Fallback to any orders without a payment transaction
      if candidates.size < needed
        more = Order.where.not(id: PaymentTransaction.select(:order_id)).limit(needed - candidates.size).to_a
        candidates += more
      end

      candidates.first(needed).each_with_index do |order, idx|
        # Create a successful installment transaction
        amount = order.total_vnd
        installment_months = [3, 6, 9, 12].sample
        installment_bank = ['VISA', 'MASTERCARD', 'JCB', 'AMEX'].sample
        monthly_rate = rand(1.0..2.0)
        installment_fee_amount = (amount * monthly_rate * installment_months / 100).round(-3)

        merch_txn_ref = "#{order.order_number}--seeder-#{Time.current.to_i}-#{idx}"
        onepay_transaction_id = "OP#{Time.current.to_i}#{rand(1000..9999)}"

        # Update order metadata (idempotent merge)
        order.update!(
          metadata: (order.metadata || {}).merge(
            'payment_method' => 'installment',
            'installment_bank' => installment_bank,
            'installment_months' => installment_months,
            'installment_fee_amount' => installment_fee_amount
          )
        )

        raw_callback = {
          'vpc_TxnResponseCode' => '0',
          'vpc_Amount' => (amount * 100).to_i,
          'vpc_Message' => 'Approved',
          'vpc_OrderInfo' => order.order_number,
          'vpc_MerchTxnRef' => merch_txn_ref,
          'vpc_Card' => installment_bank,
          'vpc_ItaBankCode' => installment_bank,
          'vpc_ItaFeeAmount' => (installment_fee_amount * 100).to_i,
          'vpc_ItaMonths' => installment_months.to_s,
          'vpc_CreatedAt' => Time.current.iso8601
        }

        PaymentTransaction.create!(
          order: order,
          onepay_transaction_id: onepay_transaction_id,
          amount: amount,
          status: '0',
          merch_txn_ref: merch_txn_ref,
          raw_callback: raw_callback
        )

  # Ensure both flags reflect a successful payment
  order.update!(payment_status: 'paid', status: 'paid') unless order.payment_status == 'paid' && order.status == 'paid'
        payment_transactions_created += 1
        puts "  -> Created installment txn for Order #{order.order_number} (fee: #{installment_fee_amount} VND)"
      end
    end
  rescue => e
    puts "Warning: failed to create extra installment transactions: #{e.message}"
  end

  puts "\n" + "="*60
  puts "Payment Transactions Seeding Complete!"
  puts "="*60
  puts "✓ Created: #{payment_transactions_created} payment transactions"

  # Ensure at least a small number of installment transactions exist for testing/admin views
  # This block is idempotent and will only create the missing number of installment transactions.
  min_installments = 3
  existing_installments = PaymentTransaction.installment_only.count
  if existing_installments < min_installments
    needed = min_installments - existing_installments
    puts "\nEnsuring at least #{min_installments} installment transactions: need #{needed} more..."

    # Prefer orders that don't yet have a payment transaction and that contain free_installment_fee products
    candidate_orders = Order.includes(order_items: :product)
                            .where.not(id: PaymentTransaction.select(:order_id))

    preferred = candidate_orders.joins(order_items: :product)
                                .where(products: { free_installment_fee: true })
                                .distinct

    candidates = (preferred.to_a + (candidate_orders.to_a - preferred.to_a)).uniq

    candidates.first(needed).each do |order|
      amount = order.total_vnd
      months = [3, 6, 9, 12].sample
      bank = ['VISA', 'MASTERCARD', 'JCB', 'AMEX'].sample
      monthly_rate = rand(1.0..3.0)
      fee = (amount * monthly_rate * months / 100).round(-3)

      # Update order metadata to reflect installment payment
      order.update!(
        metadata: (order.metadata || {}).merge(
          'payment_method' => 'installment',
          'installment_bank' => bank,
          'installment_months' => months,
          'installment_fee_amount' => fee
        )
      )

      onepay_transaction_id = "OP#{Time.current.to_i}#{rand(1000..9999)}"
      merch_txn_ref = "#{order.order_number}--#{Time.current.to_i}"

      raw_callback = {
        "vpc_TxnResponseCode" => '0',
        "vpc_Amount" => (amount * 100).to_i,
        "vpc_Message" => "Approved",
        "vpc_OrderInfo" => order.order_number,
        "vpc_MerchTxnRef" => merch_txn_ref,
        "vpc_Card" => bank,
        "vpc_ItaBankCode" => bank,
        "vpc_ItaFeeAmount" => (fee * 100).to_i,
        "vpc_ItaMonths" => months.to_s,
        "vpc_CreatedAt" => Time.current.iso8601
      }

      PaymentTransaction.create!(
        order: order,
        onepay_transaction_id: onepay_transaction_id,
        amount: amount,
        status: '0',
        merch_txn_ref: merch_txn_ref,
        raw_callback: raw_callback
      )

      puts "→ Created installment txn for #{order.order_number} (fee=#{fee}, months=#{months})"
      payment_transactions_created += 1
    end
  else
    puts "\nAlready have #{existing_installments} installment transactions, nothing to add."
  end
