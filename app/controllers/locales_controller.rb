# Persists whichever actor is signed in (staff PIN or admin login)'s
# language choice, then bounces back to where the toggle was clicked.
# Reachable by admin (no paired device) as well as shop-floor staff, so it
# cannot require a paired device — only that someone is signed in as one or
# the other.
class LocalesController < ApplicationController
  skip_before_action :require_device
  skip_before_action :require_user
  before_action :require_signed_in_actor

  def update
    locale = params[:locale]
    actor = Current.user || Current.admin
    actor&.update(locale: locale) if locale.in?(User::LOCALES)

    redirect_back fallback_location: root_path
  end

  private

  def require_signed_in_actor
    return if Current.user || Current.admin

    redirect_to root_path
  end
end
