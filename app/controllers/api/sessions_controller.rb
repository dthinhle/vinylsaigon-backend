class Api::SessionsController < Devise::SessionsController
  respond_to :json

  # POST /api/users/sign_in
  def create
    self.resource = warden.authenticate!(auth_options)
    sign_in(resource_name, resource)
    render json: {
      status: { code: 200, message: 'Signed in successfully.' },
      data: resource.as_json(only: [:id, :email])
    }, status: :ok
  end

  # DELETE /api/users/sign_out
  def destroy
    sign_out(resource_name)
    render json: {
      status: { code: 200, message: 'Signed out successfully.' }
    }, status: :ok
  end

  private

  def respond_to_on_destroy
    head :no_content
  end
end
