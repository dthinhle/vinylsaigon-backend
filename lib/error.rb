
puts 'Adding error handling module...'
module Error
  class APIError < StandardError
    INVALID_CREDENTIAL = 'Invalid credentials provided.'
    CANNOT_PROCESS_REQUEST = 'Cannot process the request.'
    AUTH_HEADER_MISSING = 'Authorization header is missing.'
    SIGNATURE_EXPIRED = 'JWT signature has expired.'
  end

  class AuthorizationError < StandardError; end
  class EmptyCartError < StandardError; end
end
