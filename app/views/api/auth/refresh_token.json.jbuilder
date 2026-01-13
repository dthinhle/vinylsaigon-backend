json.success true
json.message 'User refreshed token successfully'
json.partial! 'shared/auth/base_response', user: @user, access_token: @access_token, exp: @exp, refresh_token: @refresh_token
