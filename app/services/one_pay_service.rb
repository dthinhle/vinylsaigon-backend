# frozen_string_literal: true

require 'cgi'
require 'base64'

# Service to handle all communication with the OnePay payment gateway.
#
# Required Environment Variables:
# - ONEPAY_MERCHANT_ID: Merchant ID provided by OnePay (regular payments)
# - ONEPAY_ACCESS_CODE: Access code provided by OnePay (regular payments)
# - ONEPAY_SECURE_HASH_SECRET: Hash secret key provided by OnePay (regular payments)
# - ONEPAY_INSTALLMENT_MERCHANT_ID: Merchant ID for installment payments
# - ONEPAY_INSTALLMENT_ACCESS_CODE: Access code for installment payments
# - ONEPAY_INSTALLMENT_SECURE_HASH_SECRET: Hash secret key for installment payments
# - ONEPAY_USER: QueryDR API username (default: Administrator)
# - ONEPAY_PASSWORD: QueryDR API password (default: admin@123456)
# - ONEPAY_RETURN_URL: Return URL for payment callback
# - ONEPAY_GATEWAY_URL: Gateway endpoint (sandbox: https://mtf.onepay.vn/paygate/vpcpay.op)
# - ONEPAY_AGAIN_LINK: Link for retry payments (optional)
class OnePayService
  # Class-level method to generate a payment URL for an order.
  # @param order [Order] The order to generate the payment URL for.
  # @param ip_address [String] The customer's IP address.
  # @return [full_url, merch_txn_ref] [full_url, merch_txn_ref]
  def self.generate_payment_url(order:, ip_address:)
    new(order: order, ip_address: ip_address).generate_payment_url
  end

  # Class-level method to get available installment options.
  # @param amount [Integer] The payment amount in VND (already multiplied by 100).
  # @return [Hash] Available installment options or nil on error.
  def self.get_installment_options(amount:)
    new.get_installment_options(amount: amount)
  end

  # Class-level method to verify the callback from OnePay.
  # @param params [Hash] The parameters from the OnePay callback.
  # @return [Boolean] True if the callback is valid, false otherwise.
  def self.verify_callback(params)
    new(params: params).verify_callback
  end

  # Class-level method to query a transaction's status from OnePay.
  # @param order_number [String] The order number.
  # @param merch_txn_ref [String] The unique transaction reference.
  # @return [Hash] Parsed response from OnePay or nil on error.
  def self.query_dr(order_number:, merch_txn_ref:)
    new.query_dr(order_number: order_number, merch_txn_ref: merch_txn_ref)
  end

  def initialize(order: nil, params: nil, ip_address: nil)
    @order = order
    @params = params
    @ip_address = ip_address
  end

  # Generates the full OnePay payment URL with all required parameters and a secure hash.
  # Returns [payment_url, merch_txn_ref] so callers can persist or schedule followups.
  def generate_payment_url
    # 1. Build base parameters with original values (không encode ở đây)
    merch_txn_ref = "#{@order.order_number}--#{Time.now.to_i}"

    # Use installment credentials if this is an installment payment
    creds = @order.installment_payment? ? installment_credentials : credentials

    base_params = {
      # Các tham số tĩnh: Tài khoản OnePAY, thông số cổng thanh toán
      'vpc_Version' => '2',
      'vpc_Currency' => 'VND',
      'vpc_Command' => 'pay',
      'vpc_AccessCode' => creds[:access_code],
      'vpc_Merchant' => creds[:merchant_id],
      'vpc_ReturnURL' => ENV.fetch('ONEPAY_RETURN_URL'),
      'vpc_Locale' => 'vn',
      # Các tham số website gán giá trị động: Price, Order ID
      'vpc_MerchTxnRef' => merch_txn_ref,
      'vpc_OrderInfo' => "Payment for Order ##{@order.order_number}", # Giữ nguyên, không encode
      'vpc_Amount' => @order.total_vnd * 100,
      'vpc_TicketNo' => @ip_address
    }

    # 2. Thêm các tham số optional (moved into params before hashing so they participate)
    additional_params = {
      'AgainLink' => ENV.fetch('ONEPAY_AGAIN_LINK', 'http://localhost:3000'),
      'Title' => '3kShop Checkout'
    }

    # Add customer information if available (from order or user)
    customer_email = @order.email || @order.user&.email
    customer_phone = @order.phone_number || @order.user&.phone_number
    customer_id = @order.user_id

    additional_params['vpc_Customer_Email'] = customer_email if customer_email.present?
    additional_params['vpc_Customer_Phone'] = customer_phone if customer_phone.present?
    additional_params['vpc_Customer_Id'] = customer_id.to_s if customer_id.present?

    # Add installment-specific parameters if this is an installment payment
    if @order.installment_payment?
      additional_params['vpc_theme'] = 'ita' # Enable installment theme
      # Restrict to installment-supporting cards only
      additional_params['vpc_CardList'] = 'INTERCARD' # Only international cards support installments
    end

    Rails.logger.info("[OnePayService#generate_payment_url] Base params=#{base_params.inspect}")

    # 3. Merge optional params into the params used for hashing so they participate in secure hash
    all_for_hashing = base_params.merge(additional_params)

    # 4. Tính secure hash chỉ từ vpc_ và user_ params (calculate_secure_hash will filter/normalize)
    # Use the same credentials object that was used for the base parameters
    secure_hash = calculate_secure_hash(all_for_hashing, creds)

    # 5. Combine tất cả params cho URL (bao gồm cả additional_params and secure hash)
    all_params = base_params.merge(additional_params)
    all_params['vpc_SecureHash'] = secure_hash

    # 5. Build URL với proper encoding
    # Use correct endpoints based on environment
    # Sandbox: https://mtf.onepay.vn/paygate/vpcpay.op
    # Production: https://onepay.vn/paygate/vpcpay.op
    gateway_url = ENV.fetch('ONEPAY_GATEWAY_URL', 'https://mtf.onepay.vn/paygate/vpcpay.op')

    # Encode parameters properly cho URL
    encoded_params = all_params.map do |key, value|
      "#{key}=#{ERB::Util.url_encode(value.to_s)}"
    end.join('&')

    full_url = "#{gateway_url}?#{encoded_params}"
    [full_url, merch_txn_ref]
  end

  # Verifies the integrity of the OnePay callback by recalculating and comparing the secure hash.
  def verify_callback
    received_hash = @params['vpc_SecureHash']

    # Determine which credentials to use based on the merchant ID in the callback
    creds = if @params['vpc_Merchant'] == installment_credentials[:merchant_id]
              installment_credentials
    else
              credentials
    end

    # 1. Extract chỉ vpc_ và user_ params, loại bỏ vpc_SecureHash và vpc_SecureHashType
    params_for_hashing = @params.to_h.select do |key, value|
      key.start_with?('vpc_', 'user') &&
      key != 'vpc_SecureHash' &&
      key != 'vpc_SecureHashType' &&
      value.present?
    end

    Rails.logger.debug("[OnePayService#verify_callback] Params for callback hash verification=#{params_for_hashing.inspect}")

    # 2. Recalculate hash using the correct credentials
    calculated_hash = calculate_secure_hash(params_for_hashing, creds)

    Rails.logger.debug("[OnePayService#verify_callback] Received hash=#{received_hash} Calculated hash=#{calculated_hash}")

    # 3. Secure compare (normalize to uppercase to match demo)
    return false if received_hash.blank? || calculated_hash.blank?

    ActiveSupport::SecurityUtils.secure_compare(received_hash.to_s.upcase, calculated_hash.to_s.upcase)
  end

  # Public: Query DR (dispute/transaction status) from OnePay.
  # Returns parsed Hash on success, or nil on error.
  def query_dr(order_number:, merch_txn_ref:, is_installment: false)
    # Build correct endpoint as per demo: /msp/api/v1/vpc/invoices/queries
    # Extract base URL without the /paygate/vpcpay.op path
    gateway_url = ENV.fetch('ONEPAY_GATEWAY_URL', 'https://mtf.onepay.vn/paygate/vpcpay.op')
    base_url = gateway_url.gsub('/paygate/vpcpay.op', '')
    url = "#{base_url}/msp/api/v1/vpc/invoices/queries"

    # Use the correct credentials based on whether it's an installment payment
    creds = is_installment ? installment_credentials : credentials

    # Build payload with required authentication params as per demo
    payload = {
      'vpc_Version' => '2',
      'vpc_Command' => 'queryDR',
      'vpc_Merchant' => creds[:merchant_id],
      'vpc_AccessCode' => creds[:access_code],
      'vpc_MerchTxnRef' => merch_txn_ref,
      'vpc_User' => ENV.fetch('ONEPAY_USER', 'Administrator'),
      'vpc_Password' => ENV.fetch('ONEPAY_PASSWORD', 'admin@123456')
    }

    # Calculate secure hash for QueryDR (excludes vpc_SecureHash itself)
    secure_hash = calculate_secure_hash(payload, creds)
    payload['vpc_SecureHash'] = secure_hash

    redacted_payload = payload.dup
    redacted_payload['vpc_Password'] = '[REDACTED]'
    Rails.logger.info "[OnePayService#query_dr] Request URL=#{url} payload=#{redacted_payload.inspect}"

    begin
      uri = URI.parse(url)
      # Use form-urlencoded as per demo, not JSON
      req = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/x-www-form-urlencoded')
      req.body = URI.encode_www_form(payload)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      # WARNING: Insecure! This disables SSL certificate verification.
      # This is a workaround for local development environments where OpenSSL
      # may be misconfigured. DO NOT use this in production.
      if Rails.env.development?
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      response = http.request(req)

      Rails.logger.info "[OnePayService#query_dr] Response status=#{response.code} body=#{response.body}"

      return nil unless response.is_a?(Net::HTTPSuccess)

      # Parse form-encoded response
      parsed = CGI.parse(response.body).transform_values(&:first)
      parsed
    rescue StandardError => e
      Rails.logger.error "[OnePayService#query_dr] Error: #{e.class} #{e.message}\n#{e.backtrace.join("\n")}"
      nil
    end
  end

  private

  # Calculates the SHA256 secure hash for a given set of parameters.
  # Implementation matches exactly with demo's util.py functions
  def calculate_secure_hash(params, creds = nil)
    # 1. Get secret key (merchant_hash_code) and interpret it as HEX -> binary key
    creds ||= credentials # Use default credentials if none provided
    secret_key_hex = creds[:secure_hash_secret]
    binary_key = [secret_key_hex.to_s].pack('H*')

    # 2. Filter only vpc_ and user* params, exclude secure hash fields, and drop empty values
    # Matches demo's generate_string_to_hash() logic
    hash_params = params.to_h.select do |key, value|
      prefix_key = key[0, 4]  # First 4 characters
      (prefix_key == 'vpc_' || prefix_key == 'user') &&
        key != 'vpc_SecureHash' &&
        key != 'vpc_SecureHashType' &&
        value.present? &&
        !value.to_s.empty?  # Check for empty strings like demo
    end

    # 3. Sort lexicographically by key (matches demo's sort_param())
    sorted_params = hash_params.sort_by { |k, _v| k }

    # 4. Build string_to_hash exactly as "key1=value1&key2=value2" using raw values (no encoding)
    # Matches demo's generate_string_to_hash() output format
    hash_data = sorted_params.map { |key, value| "#{key}=#{value}" }.join('&')

    Rails.logger.debug("[OnePayService#calculate_secure_hash] Hash data=#{hash_data}")

    # 5. Compute HMAC-SHA256 using binary key and return uppercase hex string
    # Matches demo's vpc_auth() -> hmac_sha256() -> .hex().upper()
    hash_result = OpenSSL::HMAC.hexdigest('SHA256', binary_key, hash_data).upcase

    Rails.logger.debug("[OnePayService#calculate_secure_hash] Generated hash=#{hash_result}")

    hash_result
  end

  # Helper method to access OnePay credentials from environment variables.
  def credentials
    {
      merchant_id: ENV.fetch('ONEPAY_MERCHANT_ID'),
      access_code: ENV.fetch('ONEPAY_ACCESS_CODE'),
      secure_hash_secret: ENV.fetch('ONEPAY_SECURE_HASH_SECRET')
    }
  end

  # Helper method to access OnePay installment credentials from environment variables.
  def installment_credentials
    {
      merchant_id: ENV.fetch('ONEPAY_INSTALLMENT_MERCHANT_ID'),
      access_code: ENV.fetch('ONEPAY_INSTALLMENT_ACCESS_CODE'),
      secure_hash_secret: ENV.fetch('ONEPAY_INSTALLMENT_SECURE_HASH_SECRET')
    }
  end

  # Get available installment options from OnePay
  # Based on demo's get_installment function
  def get_installment_options(amount:)
    merchant_id = installment_credentials[:merchant_id]
    merchant_hash_code = installment_credentials[:secure_hash_secret]

    # Build the request URL and headers as per demo
    gateway_url = ENV.fetch('ONEPAY_GATEWAY_URL', 'https://mtf.onepay.vn/paygate/vpcpay.op')
    base_url = gateway_url.gsub('/paygate/vpcpay.op', '')
    host = URI.parse(base_url).host

    uri = "/msp/api/v1/merchants/#{merchant_id}/installments?amount=#{amount}"

    # Create signature for the installment API (uses different signing method)
    signed_header_names = ['(request-target)', '(created)', 'host', 'accept']
    accept = '*/*'

    headers = {
      'Host' => host,
      'Accept' => accept
    }

    signature = create_request_signature_ita('GET', uri, headers, signed_header_names, merchant_id, merchant_hash_code)

    request_headers = {
      'Host' => host,
      'signature' => signature,
      'accept' => accept
    }

    url = "#{base_url}#{uri}"

    Rails.logger.info "[OnePayService#get_installment_options] Request URL=#{url}"

    begin
      uri_obj = URI.parse(url)
      req = Net::HTTP::Get.new(uri_obj.request_uri, request_headers)

      response = Net::HTTP.start(uri_obj.host, uri_obj.port, use_ssl: uri_obj.scheme == 'https') do |http|
        http.request(req)
      end

      Rails.logger.info "[OnePayService#get_installment_options] Response status=#{response.code} body=#{response.body}"

      return nil unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue StandardError => e
      Rails.logger.error "[OnePayService#get_installment_options] Error: #{e.class} #{e.message}\n#{e.backtrace.join("\n")}"
      nil
    end
  end

  # Create request signature for installment API (ITA)
  # Based on demo's create_request_signature_ita function
  def create_request_signature_ita(method, uri, http_headers, signed_header_names, merchant_id, merchant_hash_code)
    created = Time.now.to_i.to_s
    lowercase_headers = {}

    http_headers.each do |key, value|
      lowercase_headers[key.downcase] = value
    end

    lowercase_headers['(request-target)'] = "#{method.downcase} #{uri}"
    lowercase_headers['(created)'] = created

    signing_string = ''
    header_names = ''

    signed_header_names.each do |header_name|
      raise "MissingRequiredHeaderException: #{header_name}" unless lowercase_headers.key?(header_name)

      signing_string += "\n" unless signing_string.empty?
      signing_string += "#{header_name}: #{lowercase_headers[header_name]}"

      header_names += ' ' unless header_names.empty?
      header_names += header_name
    end

    Rails.logger.debug "[OnePayService#create_request_signature_ita] Signing string=#{signing_string}"

    # Create HMAC-SHA512 signature and encode to base64
    hmac_key = [merchant_hash_code].pack('H*')
    signature = Base64.encode64(OpenSSL::HMAC.digest('SHA512', hmac_key, signing_string)).strip

    "algorithm=\"hs2019\", keyId=\"#{merchant_id}\", headers=\"#{header_names}\", created=#{created}, signature=\"#{signature}\""
  end
end
