# Web login for admin — username + password, independent of the
# device-pairing/PIN system. No paired device required.
class Admin::SessionsController < ApplicationController
  skip_before_action :set_current_device
  skip_before_action :set_current_user
  skip_before_action :require_device
  skip_before_action :require_user

  rate_limit to: 5, within: 1.minute, by: -> { request.remote_ip },
             with: -> { render plain: "Too many attempts, try again shortly", status: :too_many_requests },
             only: :create

  def new
  end

  def create
    admin_user = Current.shop.admin_users.active.find_by("lower(username) = ?", params[:username].to_s.downcase)

    if admin_user&.authenticate(params[:password])
      reset_session
      session[:admin_user_id] = admin_user.id
      redirect_to admin_root_path
    else
      flash.now[:alert] = "Incorrect username or password"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:admin_user_id)
    redirect_to new_admin_session_path
  end
end
