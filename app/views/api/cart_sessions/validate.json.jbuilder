json.valid @valid
if @valid
  json.expires_at @expires_at
else
  json.error 'Session expired or invalid'
end
