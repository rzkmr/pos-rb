# A single, cacheable payload of everything the offline UI needs to render
# without the server: shop identity/settings and the active menu. Consumed
# by app/javascript/lib/catalog_cache.js and stored in IndexedDB so the app
# shell (see OfflineShellsController) can boot with no connection.
class CatalogSnapshotsController < ApplicationController
  def show
    shop = Current.shop
    menu_items = shop.menu_items.active.ordered
    users = shop.users.active.order(:name)
    takeaway_counter = shop.dining_tables.takeaway_counters.first

    render json: {
      version: [ shop.updated_at, menu_items.maximum(:updated_at), users.maximum(:updated_at),
                 takeaway_counter&.updated_at ].compact.max.to_i,
      generated_at: Time.current.iso8601,
      shop: {
        name: shop.name,
        address: shop.address,
        pan: shop.pan,
        invoice_footer: shop.invoice_footer,
        invoice_prefix: shop.invoice_prefix,
        vat_rate_bp: shop.vat_rate_bp,
        service_charge_rate_bp: shop.service_charge_rate_bp
      },
      menu_items: menu_items.map { |item| serialize_menu_item(item) },
      # id/name/role ONLY — never pin. The offline shell shows this list so
      # staff can claim who's on the counter while cold-started (see
      # Sync::ActingUser); it is an attribution picker, not a login, so the
      # PIN must never leave the server in this payload.
      users: users.map { |user| { id: user.id, name: user.name, role: user.role } },
      takeaway_counter: takeaway_counter && { label: takeaway_counter.label }
    }
  end

  private

  def serialize_menu_item(item)
    {
      id: item.id,
      name: item.name,
      category: item.category,
      gross_price_paisa: item.gross_price_paisa,
      gross_price_rupees: item.gross_price_rupees
    }
  end
end
