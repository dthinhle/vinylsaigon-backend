class Admin::DashboardController < Admin::BaseController
  def index
    @recent_changes = PaperTrail::Version
      .where(item_type: ['Product', 'Blog'])
      .order(created_at: :desc)
      .limit(10)
      .includes(:item)
  end
end
