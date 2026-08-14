class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: [ :edit, :update, :destroy ]

  def index
    @users = Current.shop.users.order(:name)
  end

  def new
    @user = Current.shop.users.new
  end

  def create
    @user = Current.shop.users.new(user_params)
    if @user.save
      AuditEvent.record!(action: "user_created", subject: @user, admin_user: Current.admin, payload: { name: @user.name, role: @user.role })
      redirect_to admin_users_path, notice: "User added"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    pin_changed = user_update_params.key?(:pin)
    if @user.update(user_update_params)
      AuditEvent.record!(
        action: "user_updated", subject: @user, admin_user: Current.admin,
        payload: { name: @user.name, role: @user.role, active: @user.active, pin_reset: pin_changed }
      )
      redirect_to admin_users_path, notice: "User updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @user.update_column(:active, false)
    AuditEvent.record!(action: "user_deactivated", subject: @user, admin_user: Current.admin)
    redirect_to admin_users_path, notice: "User deactivated"
  end

  private

  def set_user
    @user = Current.shop.users.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name, :role, :pin, :active)
  end

  def user_update_params
    params.require(:user).permit(:name, :role, :active, :pin).tap do |permitted|
      permitted.delete(:pin) if permitted[:pin].blank?
    end
  end
end
