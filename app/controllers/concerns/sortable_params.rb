module SortableParams
  extend ActiveSupport::Concern

  private

  def parse_sort_by_params(params)
    return params unless params[:sort_by].present?

    sort_parts = params[:sort_by].split('_')
    params[:direction] = sort_parts.pop
    params[:sort] = sort_parts.join('_')
    params
  end
end
