# frozen_string_literal: true

class APIError
  AUTH_HEADER_MISSING = 'Missing authorization header'
  CANNOT_PROCESS_REQUEST = 'Failed to process the request'
  SIGNATURE_EXPIRED = 'Signature has expired'
  INVALID_CREDENTIAL = 'Invalid email or password'
  MISSING_CREDENTIAL = 'Missing email or password'
end
