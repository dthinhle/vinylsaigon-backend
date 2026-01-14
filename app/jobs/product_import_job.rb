class ProductImportJob < ApplicationJob
  queue_as :background

  def perform(file_path:, import_id:, import_options:)
    ProductImportService.call(
      file_path: file_path,
      import_id: import_id,
      import_options: import_options
    )
  ensure
    File.delete(file_path) if File.exist?(file_path)
  end
end
