import BulkActionsController from "./bulk_actions_controller"

export default class extends BulkActionsController {
  getResourceName() {
    return 'blog'
  }

  getDefaultDeleteUrl() {
    return '/admin/blogs/destroy_selected'
  }

  getConfirmMessage() {
    return "Are you sure you want to delete the selected blogs? This action cannot be undone."
  }
}
