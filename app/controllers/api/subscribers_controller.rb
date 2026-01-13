class Api::SubscribersController < Api::BaseController
  def create
    @subscriber = Subscriber.new(subscriber_params)

    if @subscriber.save
      render json: @subscriber, status: :created
    else
      status = @subscriber.errors.any? { |err| err.type == :taken } ? :conflict : :unprocessable_entity
      render json: { errors: @subscriber.errors.full_messages }, status:
    end
  end

  private

  def subscriber_params
    params.require(:subscriber).permit(:email)
  end
end
