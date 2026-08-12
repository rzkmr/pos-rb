module RequireAdmin
  extend ActiveSupport::Concern

  included do
    before_action :require_admin
  end

  private

  def require_admin
    return if Current.user&.role == "admin"

    render plain: "Admin only", status: :forbidden
  end
end
