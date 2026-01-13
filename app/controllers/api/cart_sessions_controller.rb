module Api
  class CartSessionsController < Api::BaseController
    def create
      @cart = SessionTrackingService.create_session
      @expires_at = SESSION_EXPIRES_IN_DAYS.days.from_now

      render status: :created
    end

    def validate
      session_id = params[:session_id]
      @valid = SessionTrackingService.validate_session(session_id)
      @expires_at = 30.days.from_now if @valid

      render status: @valid ? :ok : :unprocessable_entity
    end
  end
end
