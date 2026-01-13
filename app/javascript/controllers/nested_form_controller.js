// baka-backend/app/javascript/controllers/nested_form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["removeButton", "addButton", "destroy"];

  connect() {
    this.setupVariantNameAutoPopulate()
  }

  sanitizeSlug(text) {
    return text
      .toString()
      .toLowerCase()
      .trim()
      .replace(/\s+/g, '-')
      .replace(/[^\w\-]+/g, '')
      .replace(/\-\-+/g, '-')
      .replace(/^-+/, '')
      .replace(/-+$/, '')
  }

  setupVariantNameAutoPopulate() {
    const nameInput = this.element.querySelector('input[name*="[name]"]')
    const skuInput = this.element.querySelector('input[name*="[sku]"]')
    const slugInput = this.element.querySelector('input[name*="[slug]"]')

    if (!nameInput || !skuInput || !slugInput) return

    nameInput.addEventListener('blur', () => {
      const variantName = nameInput.value.trim()
      if (!variantName) return

      const form = this.element.closest('form')
      const productSkuInput = form ? form.querySelector('[name="product[sku]"]') : null
      const productSku = productSkuInput ? productSkuInput.value.trim() : ''

      const variantSlug = this.sanitizeSlug(variantName)

      if (variantSlug) {
        if (!slugInput.value.trim()) {
          slugInput.value = variantSlug
        }

        if (!skuInput.value.trim()) {
          if (productSku) {
            skuInput.value = `${productSku}-${variantSlug.toUpperCase()}`
          } else {
            skuInput.value = variantSlug.toUpperCase()
          }
        }
      }
    })
  }

  remove(event) {
    event.preventDefault()
    const variantForm = event.target.closest("[data-controller='nested-form']")
    if (!variantForm) return

    const destroyCheckbox = variantForm.querySelector("input[type='checkbox'][name*='[_destroy]']")
    if (destroyCheckbox) {
      destroyCheckbox.checked = true
      destroyCheckbox.dispatchEvent(new Event('change', { bubbles: true }))
    }
  }

  toggleDestroy(event) {
    const checkbox = event.target
    const isMarkedForDestroy = checkbox.checked
    const variantForm = this.element
    const variantInnerForm = this.element.querySelector('.variant-input-wrapper')

    if (isMarkedForDestroy) {
      this.disableForm(variantForm)
      variantInnerForm.classList.add('opacity-50')
      variantForm.setAttribute('data-marked-for-destroy', 'true')

      // Add pointer-events-none to all children except the destroy checkbox section
      const allElements = variantForm.querySelectorAll('*')
      allElements.forEach(el => {
        if (!el.contains(checkbox) && el !== checkbox && !checkbox.contains(el)) {
          el.style.pointerEvents = 'none'
        }
      })
    } else {
      this.enableForm(variantForm)
      variantInnerForm.classList.remove('opacity-50')
      variantForm.removeAttribute('data-marked-for-destroy')

      // Remove pointer-events-none from all children
      const allElements = variantForm.querySelectorAll('*')
      allElements.forEach(el => {
        el.style.pointerEvents = ''
      })
    }
  }

  disableForm(container) {
    const formElements = container.querySelectorAll('input, textarea, select, button')
    formElements.forEach(element => {
      // Skip the _destroy checkbox
      if (element.type === 'checkbox' && element.name && element.name.includes('[_destroy]')) {
        return
      }
      element.disabled = true
    })
  }

  enableForm(container) {
    const formElements = container.querySelectorAll('input, textarea, select, button')
    formElements.forEach(element => {
      // Skip the _destroy checkbox - it should remain enabled
      if (element.type === 'checkbox' && element.name && element.name.includes('[_destroy]')) {
        return
      }
      element.disabled = false
    })
  }

  add(event) {
    event.preventDefault()
    const variantsContainer = document.querySelector(".product-variants-form-container")
    if (!variantsContainer) return

    const template = document.getElementById("variant-form-template")
    if (!template) return
    const fragment = template.content.cloneNode(true)
    const newVariant = fragment.querySelector("[data-controller='nested-form']")
    // Generate a unique index using a simple integer timestamp
    const uniqueIndex = Date.now()

    // Replace all static NEW_RECORD index in input/select/textarea names and ids with the unique index
    Array.from(newVariant.querySelectorAll("input, select, textarea, label")).forEach(el => {
      if (el.name) {
        el.name = el.name.replace(/NEW_RECORD/g, uniqueIndex)
      }
      if (el.id) {
        el.id = el.id.replace(/NEW_RECORD/g, uniqueIndex)
      }
      if (el.htmlFor) {
        el.htmlFor = el.htmlFor.replace(/NEW_RECORD/g, uniqueIndex)
      }
    })

    // Ensure _destroy is false and clear values
    Array.from(newVariant.querySelectorAll("input, select, textarea")).forEach(input => {
      if (input.type === "checkbox" && input.name.endsWith("[_destroy]")) {
        input.checked = false
      } else if (input.type === "checkbox" || input.type === "radio") {
        input.checked = false
      } else {
        input.value = ""
      }
    })

    newVariant.style.display = ""

    let insertedElement
    if (
      event.target &&
      variantsContainer.contains(event.target) &&
      event.target.parentNode === variantsContainer
    ) {
      variantsContainer.insertBefore(newVariant, event.target)
      insertedElement = event.target.previousElementSibling
    } else {
      variantsContainer.appendChild(newVariant)
      insertedElement = variantsContainer.lastElementChild
    }

    // Scroll to the newly added variant
    if (insertedElement) {
      setTimeout(() => {
        insertedElement.scrollIntoView({
          behavior: "smooth",
          block: "center",
          inline: "nearest"
        })
      }, 100)
    }
  }
}
