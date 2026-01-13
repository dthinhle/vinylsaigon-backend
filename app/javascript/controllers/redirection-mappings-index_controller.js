import BulkActionsController from "./bulk_actions_controller"

export default class extends BulkActionsController {
  updateBulkActionUI() {
    const selectedCount = this.rowCheckboxTargets.filter(cb => cb.checked).length
    const totalCount = this.rowCheckboxTargets.length

    // Custom behavior for delete button visibility
    if (this.hasDeleteButtonTarget) {
      if (selectedCount > 0) {
        this.deleteButtonTarget.classList.remove("hidden")
        this.deleteButtonTarget.classList.add("flex")
      } else {
        this.deleteButtonTarget.classList.add("hidden")
        this.deleteButtonTarget.classList.remove("flex")
      }
    }

    // Standard bulk actions row handling
    if (this.hasBulkActionsRowTarget) {
      if (selectedCount > 0) {
        this.bulkActionsRowTarget.setAttribute('data-selected-rows', '')
      } else {
        this.bulkActionsRowTarget.removeAttribute('data-selected-rows')
      }
    }

    // Toggle all checkbox state
    if (this.hasToggleAllCheckboxTarget) {
      if (selectedCount === 0) {
        this.toggleAllCheckboxTarget.checked = false
        this.toggleAllCheckboxTarget.indeterminate = false
      } else if (selectedCount === totalCount) {
        this.toggleAllCheckboxTarget.checked = true
        this.toggleAllCheckboxTarget.indeterminate = false
      } else {
        this.toggleAllCheckboxTarget.checked = false
        this.toggleAllCheckboxTarget.indeterminate = true
      }
    }
  }

  getResourceName() {
    return 'id'  // Uses 'ids[]' instead of 'redirection_mapping_ids[]'
  }

  getDefaultDeleteUrl() {
    return '/admin/redirection_mappings/destroy_selected'
  }

  getConfirmMessage() {
    return "Are you sure you want to delete the selected redirection mappings? This action cannot be undone."
  }

  getDeleteSuccessMessage() {
    return "Selected mappings deleted successfully."
  }

  getDeleteErrorMessage() {
    return "Failed to delete selected mappings."
  }
}
