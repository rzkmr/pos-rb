module Sync
  module Handlers
    # Raised by a handler for a permanently-invalid action (bad references,
    # a stale status transition, ...) — distinct from a transient failure,
    # so Sync::ActionsController can tell the client to stop retrying this
    # one instead of leaving it stuck retrying forever.
    Rejected = Class.new(StandardError)
  end
end
