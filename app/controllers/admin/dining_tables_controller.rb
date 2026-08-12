class Admin::DiningTablesController < Admin::BaseController
  before_action :set_dining_table, only: [ :edit, :update, :destroy ]

  def index
    @dining_tables = Current.shop.dining_tables.ordered
  end

  def new
    @dining_table = Current.shop.dining_tables.new
  end

  def create
    @dining_table = Current.shop.dining_tables.new(dining_table_params)
    if @dining_table.save
      redirect_to admin_dining_tables_path, notice: "Table added"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @dining_table.update(dining_table_params)
      redirect_to admin_dining_tables_path, notice: "Table updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @dining_table.destroy
      redirect_to admin_dining_tables_path, notice: "Table removed"
    else
      redirect_to admin_dining_tables_path, alert: @dining_table.errors.full_messages.to_sentence
    end
  end

  private

  def set_dining_table
    @dining_table = Current.shop.dining_tables.find(params[:id])
  end

  def dining_table_params
    params.require(:dining_table).permit(:label, :seats, :position)
  end
end
