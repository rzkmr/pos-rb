class Admin::SalesController < Admin::BaseController
  def show
    date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    @daily_sales = DailySales.new(shop: Current.shop, date: date)
  rescue Date::Error
    redirect_to admin_sales_path, alert: "Invalid date"
  end
end
