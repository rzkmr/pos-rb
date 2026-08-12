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
      redirect_to root_path
    else
      flash.now[:alert] = "Incorrect PIN"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:user_id)
    redirect_to new_session_path
  end
end
