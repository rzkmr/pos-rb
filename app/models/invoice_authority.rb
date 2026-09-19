# Lifecycle for the single-writer lock that makes offline invoice issuance
# safe. See db/migrate/*_create_invoice_authority_grants for why this is a
# DB-enforced partial unique index and not just an application check, and
# Billing.issue_invoice!'s guard for where the lock actually bites.
class InvoiceAuthority
  GRANT_DURATION = 15.minutes

  AlreadyGranted = Class.new(StandardError)

  # Takes the live grant for shop if none exists — raises AlreadyGranted
  # (never silently returns the other grant) if one does, since the caller
  # must know it did NOT get authority rather than assume it did.
  #
  # user: defaults to Current.user for the common case (a real signed-in
  # session acquiring the grant) but accepts an explicit override — needed
  # when release! is called from Sync::OfflineInvoiceIngest, where the
  # session doing the syncing may differ from (or not exist alongside) the
  # acting_user_id attribution on the offline sale itself.
  def self.acquire!(shop:, device:, user: Current.user)
    shop.with_lock do
      raise AlreadyGranted if InvoiceAuthorityGrant.live.exists?(shop: shop)

      financial_year = BikramSambat.fiscal_year_for(Date.current)
      grant = InvoiceAuthorityGrant.create!(
        shop: shop, device: device, financial_year: financial_year,
        granted_sequence: shop.invoice_sequence,
        granted_at: Time.current, expires_at: GRANT_DURATION.from_now
      )

      AuditEvent.record!(
        action: "invoice_authority_granted", subject: grant, device: device, user: user,
        payload: { financial_year: financial_year, granted_sequence: grant.granted_sequence }
      )

      grant
    end
  end

  # Extends a live grant while its device is still reachable — piggybacked
  # on the existing /heartbeat poll (connectivity_controller.js) rather
  # than a separate request.
  def self.heartbeat!(grant)
    return unless grant.released_at.nil?

    grant.update!(expires_at: GRANT_DURATION.from_now)
  end

  def self.release!(grant, user: Current.user)
    return if grant.released_at

    grant.update!(released_at: Time.current)
    AuditEvent.record!(
      action: "invoice_authority_released", subject: grant, device: grant.device, user: user,
      payload: { last_reported_sequence: grant.last_reported_sequence }
    )
  end

  # Admin escape hatch for a lost or bricked device — the only way to
  # unblock billing if the holding device never comes back. Dangerous: if
  # the device DOES reconnect later with unreported invoices, that's a
  # genuine two-writer situation. Sync::OfflineInvoiceIngest's contiguity
  # check is what catches that after the fact; this method only records
  # who did it and why.
  def self.force_release!(grant, admin:, reason:)
    grant.update!(released_at: Time.current)
    AuditEvent.record!(
      action: "invoice_authority_force_released", subject: grant, admin_user: admin,
      payload: { reason: reason, last_reported_sequence: grant.last_reported_sequence }
    )
  end

  def self.live_for(shop)
    InvoiceAuthorityGrant.live.find_by(shop: shop)
  end

  def self.ingesting?
    Current.ingesting_invoice_authority == true
  end
end
