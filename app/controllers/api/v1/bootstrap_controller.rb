# First run, and after a 409 cursor_too_old from Api::V1::DeltaController.
# Returns everything the client needs to work fully offline — see
# API-SPEC.md §2. Mirrors CatalogSnapshotsController's payload shape
# (menu, shop settings, users for attribution) plus dining_tables and the
# current api_sync_cursor so the client knows where to resume /delta from.
class Api::V1::BootstrapController < Api::V1::BaseController
  def show
    shop = Current.shop

    render json: {
      server_time: Time.current.iso8601,
      cursor: shop.api_sync_cursor,
      shop: shop_payload(shop),
      device: device_payload(Current.device),
      users: shop.users.active.order(:name).map { |user| user_payload(user) },
      dining_tables: shop.dining_tables.ordered.map { |table| dining_table_payload(table) },
      menu_items: shop.menu_items.active.ordered.map { |item| menu_item_payload(item) }
    }
  end

  private

  def shop_payload(shop)
    {
      id: shop.id,
      name: shop.name,
      address: shop.address,
      pan: shop.pan,
      vat_rate_bp: shop.vat_rate_bp,
      service_charge_rate_bp: shop.service_charge_rate_bp,
      invoice_fy: shop.invoice_fy,
      invoice_prefix: shop.invoice_prefix,
      invoice_footer: shop.invoice_footer
    }
  end

  def device_payload(device)
    { id: device.id, label: device.label, kind: device.kind, last_seen_at: device.last_seen_at&.iso8601 }
  end

  # id/role/name ONLY — never pin. See CatalogSnapshotsController's
  # identical comment; a PIN must never leave the server in this payload.
  def user_payload(user)
    { id: user.id, name: user.name, role: user.role }
  end

  def dining_table_payload(table)
    { id: table.id, label: table.label, seats: table.seats, position: table.position, takeaway: table.takeaway }
  end

  def menu_item_payload(item)
    {
      id: item.id, name: item.name, category: item.category,
      gross_price_paisa: item.gross_price_paisa, gross_price_rupees: item.gross_price_rupees,
      variants: item.variants, active: item.active, position: item.position
    }
  end
end
