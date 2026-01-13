import BulkActionsController from "./bulk_actions_controller"

export default class extends BulkActionsController {
  getResourceName() {
    return 'customer'
  }

  getDefaultDeleteUrl() {
    return '/admin/customers/destroy_selected'
  }

  confirmDelete() {
    // Customers controller doesn't use window.confirm in the original code
    // It relies on data-controller='confirm' for confirmation UI
    return true
  }
}
