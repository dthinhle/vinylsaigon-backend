import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "rowCheckbox",
    "deleteButton",
    "bulkActionsRow",
    "toggleAllCheckbox"
  ]

  connect() {
    this.updateBulkActionUI()
  }

  toggleAll(event) {
    const checked = event.target.checked
    this.rowCheckboxTargets.forEach(cb => {
      cb.checked = checked
    })
    this.updateBulkActionUI()
  }

  selectRow() {
    this.updateBulkActionUI()
  }

  updateBulkActionUI() {
    const selectedCount = this.rowCheckboxTargets.filter(cb => cb.checked).length
    const totalCount = this.rowCheckboxTargets.length

    if (this.hasBulkActionsRowTarget) {
      if (selectedCount > 0) {
        this.bulkActionsRowTarget.setAttribute('data-selected-rows', '')
      } else {
        this.bulkActionsRowTarget.removeAttribute('data-selected-rows')
      }
    }

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

  async deleteSelected(event) {
    event.preventDefault()
    const selectedIds = this.getSelectedIds()

    if (selectedIds.length === 0) return

    if (!this.confirmDelete()) {
      return
    }

    const actionUrl = this.getDeleteUrl()
    const formData = this.buildDeleteFormData(selectedIds)

    this.removeErrorElement()

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
        throw new Error(data.error || this.getDeleteErrorMessage())
      }

      if (response.headers.get('content-type')?.includes('application/json')) {
        const data = await response.json()
        if (data.success) {
          this.removeSelectedRows()
          this.showToast(this.getDeleteSuccessMessage(), "success")
          this.updateBulkActionUI()
        } else {
          throw new Error(data.error || data.message || this.getDeleteErrorMessage())
        }
      } else {
        window.location.reload()
      }
    } catch (error) {
      console.error('Delete error:', error)
      this.showToast(error.message || "An error occurred during deletion.", "error")
    }
  }

  getSelectedIds() {
    return this.rowCheckboxTargets
      .filter(cb => cb.checked)
      .map(cb => cb.value)
  }

  confirmDelete() {
    return window.confirm(this.getConfirmMessage())
  }

  getConfirmMessage() {
    return "Are you sure you want to delete the selected items? This action cannot be undone."
  }

  getDeleteUrl() {
    return this.deleteButtonTarget.dataset.actionUrl || this.getDefaultDeleteUrl()
  }

  getDefaultDeleteUrl() {
    return '/admin/items/destroy_selected'
  }

  getResourceName() {
    return 'item'
  }

  getResourceNamePlural() {
    return `${this.getResourceName()}s`
  }

  buildDeleteFormData(selectedIds) {
    const csrfToken = this.getCsrfToken()
    const formData = new FormData()

    if (csrfToken) {
      formData.append('authenticity_token', csrfToken)
    }

    selectedIds.forEach(id => {
      formData.append(`${this.getResourceName()}_ids[]`, id)
    })

    return formData
  }

  getCsrfToken() {
    const tokenElem = document.querySelector('meta[name="csrf-token"]')
    return tokenElem ? tokenElem.content : null
  }

  removeSelectedRows() {
    this.rowCheckboxTargets
      .filter(cb => cb.checked)
      .forEach(cb => cb.closest('tr')?.remove())
  }

  removeErrorElement() {
    const errorElem = document.getElementById('batch-delete-error')
    if (errorElem) errorElem.remove()
  }

  getDeleteSuccessMessage() {
    return `Selected ${this.getResourceNamePlural()} deleted successfully.`
  }

  getDeleteErrorMessage() {
    return `Failed to delete selected ${this.getResourceNamePlural()}.`
  }

  showToast(message, type = "info") {
    const toast = document.createElement('div')
    toast.textContent = message

    const baseClasses = "fixed top-4 right-4 px-4 py-2 rounded shadow-lg z-50 transition-opacity duration-500"
    const typeClasses = type === "success"
      ? "bg-green-600 text-white"
      : type === "error"
        ? "bg-red-600 text-white"
        : "bg-blue-600 text-white"

    toast.className = `${baseClasses} ${typeClasses}`
    document.body.appendChild(toast)

    setTimeout(() => {
      toast.style.opacity = '0'
      setTimeout(() => toast.remove(), 500)
    }, type === "error" ? 5000 : 3000)
  }
}
