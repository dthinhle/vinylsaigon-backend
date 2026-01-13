module Api
  class UsersController < Api::BaseController
    before_action :authenticate_user!

    def profile
    end

    def update
      service = UserService.new(@user)
      result = service.update(user_params)

      if result[:success]
        render :profile, status: :ok
      else
        render json: {
          error: 'Failed to update profile',
          messages: result[:errors]
        }, status: :unprocessable_entity
      end
    end

    private

    def user_params
      params.require(:user).permit(:name, :phone_number, :subscribe_newsletter)
    end
  end
end
