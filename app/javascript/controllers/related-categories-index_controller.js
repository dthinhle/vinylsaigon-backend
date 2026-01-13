import BulkActionsController from "./bulk_actions_controller"

export default class extends BulkActionsController {
  static targets = [...BulkActionsController.targets, "bulkWeight"]

  getResourceName() {
    return 'related_category'
  }

  getDefaultDeleteUrl() {
    return '/admin/related_categories/destroy_selected'
  }

  getDeleteErrorMessage() {
    return "Failed to delete selected relationships."
  }

  getDeleteSuccessMessage() {
    return "Selected relationships deleted successfully."
  }

  async updateWeight(event) {
    event.preventDefault()
    const selectedIds = this.getSelectedIds()

    if (selectedIds.length === 0) {
      this.showToast("No relationships selected.", "error")
      return
    }

    const weight = this.bulkWeightTarget.value
    if (!weight) {
      this.showToast("Please select a weight value.", "error")
      return
    }

    const csrfToken = this.getCsrfToken()
    const actionUrl = event.target.dataset.actionUrl || '/admin/related_categories/bulk_update_weight'
    const formData = new FormData()

    if (csrfToken) {
      formData.append('authenticity_token', csrfToken)
    }

    selectedIds.forEach(id => {
      formData.append('related_category_ids[]', id)
    })
    formData.append('weight', weight)

    try {
      const response = await fetch(actionUrl, {
        method: 'POST',
        body: formData,
        headers: {
          'Accept': 'application/json'
        }
      })

      if (!response.ok) {
        const data = await response.json().catch(() => ({}))
        throw new Error(data.error || "Failed to update selected relationships.")
      }

      if (response.headers.get('content-type')?.includes('application/json')) {
        const data = await response.json()
        if (data.success) {
          this.showToast(data.message, "success")
          // Reload page to show updated weights
          setTimeout(() => window.location.reload(), 1000)
        } else {
          throw new Error(data.message || "Failed to update selected relationships.")
        }
      } else {
        window.location.reload()
      }
    } catch (error) {
      console.error('Update error:', error)
      this.showToast(error.message || "An error occurred while updating relationships.", "error")
    }
  }
}
