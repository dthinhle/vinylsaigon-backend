import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["categorySelect", "relatedCategorySelect", "weightSelect"];

  connect() {
    this.validateSelections()
  }

  validateSelections() {
    // Prevent selecting the same category for both dropdowns
    if (this.hasCategorySelectTarget && this.hasRelatedCategorySelectTarget) {
      this.categorySelectTarget.addEventListener('change', () => this.updateRelatedOptions())
      this.relatedCategorySelectTarget.addEventListener('change', () => this.updateCategoryOptions())
    }
  }

  updateRelatedOptions() {
    const selectedCategoryId = this.categorySelectTarget.value
    const relatedOptions = this.relatedCategorySelectTarget.querySelectorAll('option')

    relatedOptions.forEach(option => {
      if (option.value === selectedCategoryId && option.value !== '') {
        option.disabled = true
        option.style.color = '#999'
      } else {
        option.disabled = false
        option.style.color = ''
      }
    })

    // Reset related category if it's the same as selected category
    if (this.relatedCategorySelectTarget.value === selectedCategoryId && selectedCategoryId !== '') {
      this.relatedCategorySelectTarget.value = ''
    }
  }

  updateCategoryOptions() {
    const selectedRelatedId = this.relatedCategorySelectTarget.value
    const categoryOptions = this.categorySelectTarget.querySelectorAll('option')

    categoryOptions.forEach(option => {
      if (option.value === selectedRelatedId && option.value !== '') {
        option.disabled = true
        option.style.color = '#999'
      } else {
        option.disabled = false
        option.style.color = ''
      }
    })

    // Reset category if it's the same as selected related category
    if (this.categorySelectTarget.value === selectedRelatedId && selectedRelatedId !== '') {
      this.categorySelectTarget.value = ''
    }
  }
}
