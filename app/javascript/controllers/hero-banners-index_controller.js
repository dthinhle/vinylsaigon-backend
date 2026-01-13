import BulkActionsController from "./bulk_actions_controller"

export default class extends BulkActionsController {
  getResourceName() {
    return 'hero_banner'
  }

  getDefaultDeleteUrl() {
    return '/admin/hero_banners/destroy_selected'
  }

  getConfirmMessage() {
    return "Are you sure you want to delete the selected hero banners? This action cannot be undone."
  }

  getDeleteSuccessMessage() {
    return "Selected hero banners deleted successfully."
  }

  getDeleteErrorMessage() {
    return "Failed to delete selected hero banners."
  }
}
