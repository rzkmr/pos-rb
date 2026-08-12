module ShopScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :shop
    default_scope { where(shop: Current.shop) if Current.shop }

    before_validation { self.shop ||= Current.shop }
  end
end
