class Admin::CollectionsController < Admin::BaseController
  before_action :set_collection, only: [:edit, :update, :destroy]

  def index
    @collections = ProductCollection.where(deleted_at: nil)
                                   .order(:name)
    @pagy, @collections = pagy(@collections, limit: 25)
  end

  def new
    @collection = ProductCollection.new
  end

  def edit
  end

  def create
    permitted = collection_params
    attrs = permitted.except(:thumbnail)
    @collection = ProductCollection.new(attrs)

    if @collection.save
      if permitted[:thumbnail].present?
        @collection.thumbnail.attach(permitted[:thumbnail])
      end
      redirect_to admin_collections_path, notice: 'Collection was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    permitted = collection_params
    attrs = permitted.except(:thumbnail, :product_ids)

    if @collection.update(attrs)
      if permitted[:thumbnail].present?
        @collection.thumbnail.purge_later if @collection.thumbnail.attached?
        @collection.thumbnail.attach(permitted[:thumbnail])
      end

      unless @collection.seeded_collection?
        @collection.product_ids = permitted[:product_ids] if permitted[:product_ids]
      end

      redirect_to admin_collections_path, notice: 'Collection was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @collection.seeded_collection?
      redirect_to admin_collections_path, alert: 'Auto-generated collections cannot be deleted.'
    elsif @collection.destroy
      redirect_to admin_collections_path, notice: 'Collection deleted successfully.'
    else
      redirect_to admin_collections_path, alert: 'Failed to delete collection.'
    end
  end

  private

  def set_collection
    @collection = ProductCollection.find(params[:id])
  end

  def collection_params
    params.require(:product_collection).permit(
      :name,
      :description,
      :active,
      :thumbnail,
      product_ids: []
    )
  end
end
