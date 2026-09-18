# Persists whichever actor is signed in (staff PIN or admin login)'s
# language choice, then bounces back to where the toggle was clicked. Also
# reachable from the login screens themselves before any actor exists (see
# sessions/new and admin/sessions/new) — with no actor to save a
# preference on, the choice is kept in session[:locale] for that browser's
# pre-login requests instead (see Authentication#with_locale).
# Reachable by admin (no paired device) as well as shop-floor staff, so it
# cannot require a paired device or a signed-in user.
class LocalesController < ApplicationController
  skip_before_action :require_device
  skip_before_action :require_user

  def update
    locale = params[:locale]

    if locale.in?(User::LOCALES)
      actor = Current.user || Current.admin
      actor ? actor.update(locale: locale) : session[:locale] = locale
    end

    redirect_back fallback_location: root_path
  end
end
