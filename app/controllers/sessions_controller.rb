class SessionsController < ApplicationController
  skip_before_action :require_user

  rate_limit to: 5, within: 1.minute, by: -> { Current.device&.id || request.remote_ip },
             with: -> { render plain: "Too many attempts, try again shortly", status: :too_many_requests },
             only: :create

  def new
  end

  def create
    user = Current.shop.users.active.find_by(id: params[:user_id])

    if user&.authenticate_pin(params[:pin])
      session[:user_id] = user.id
      # Binds the session to the device it was created on — see
      # Authentication#set_current_user, which refuses to honor
      # session[:user_id] if the paired device on the current request
      # doesn't match. A shared-tablet PIN session is scoped to one
      # device, one at a time, even though many staff share that device.
      session[:device_id] = Current.device.id
      redirect_to root_path
    else
      flash.now[:alert] = "Incorrect PIN"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:user_id)
    session.delete(:device_id)
    redirect_to new_session_path
  end
end
