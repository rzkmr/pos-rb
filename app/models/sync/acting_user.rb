# Resolves who to attribute an offline-queued action to. The normal case
# is Current.user (a real signed-in session) — but a cold-started offline
# shell may have never signed in at all (see OfflineShellsController,
# reachable with no device pairing or session), so the payload can carry a
# client-claimed acting_user_id instead. That claim is re-validated here
# against the shop's actual active users — it is NOT authentication (no
# PIN is checked offline; see lib/identity.js), only attribution, and an
# unknown or deactivated id is rejected outright rather than silently
# falling back to nobody. CLAUDE.md invariant #8 requires a real user on
# every audited action; this is where that's enforced for the cold-start
# path specifically.
module Sync
  class ActingUser
    Unresolved = Class.new(StandardError)

    def self.resolve!(shop:, current_user:, payload:)
      return current_user if current_user

      acting_user_id = payload["acting_user_id"]
      raise Unresolved, "no signed-in user and no acting_user_id supplied" unless acting_user_id

      user = shop.users.active.find_by(id: acting_user_id)
      raise Unresolved, "acting_user_id #{acting_user_id} is not an active user for this shop" unless user

      user
    end
  end
end
