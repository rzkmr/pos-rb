# The one HTML route the Service Worker is allowed to cache (CLAUDE.md
# invariant #4, reworded — see service-worker.js). Deliberately renders no
# transactional data: no session, no cart, no totals, no user name. Every
# dynamic value on this page is filled in client-side from IndexedDB by
# app/javascript/lib/catalog_cache.js, so a stale cached copy can never show
# stale money — there is no money in the markup to begin with.
class OfflineShellsController < ApplicationController
  skip_before_action :require_device
  skip_before_action :require_user
  skip_before_action :redirect_to_setup_if_needed

  def show
    render layout: "application"
  end
end
