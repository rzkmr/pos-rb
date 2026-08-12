class DiningTablesController < ApplicationController
  def index
    @dining_tables = Current.shop.dining_tables.ordered
  end
end
