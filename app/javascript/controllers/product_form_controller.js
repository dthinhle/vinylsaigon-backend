// vinylsaigon-backend/app/javascript/controllers/product_form_controller.js
import { Controller } from "@hotwired/stimulus"
import TomSelect from "tom-select"

const STATUS_VALUES = ["active", "inactive", "discontinued", "temporarily_unavailable"]
const FLAG_VALUES = [
  "not free shipping",
  "backorder",
  "arrive soon",
  "just arrived"
]

export default class extends Controller {
  static targets = [
    "nameError",
    "skuError",
    "slugError",
    "originalPriceError",
    "currentPriceError",
    "originalPriceInput",
    "currentPriceInput",
    "statusError",
    "shortDescriptionError",
    "metaTitleError",
    "metaDescriptionError",
    "weightError",
    "descriptionError",
    "sortOrderError",
    "categorySelect",
    "brandsSelect",
    "collectionsSelect",
    "tagsSelect",
    "relatedProductsSelect",
    "categoryError",
    "brandsError",
    "collectionsError",
    "tagsError",
    "featuredError",
    "flagsError",
    "variantModeToggle",
    "variantModeLabel",
    "singleProductImages",
    "singleProductImageInput",
    "variantsContainer",
    "variantControls",
    "variantsList",
    "variantTemplate",
    "variantForm",
    "addVariantButton",
    "removeVariantButton",
    "arriveSoonFlag",
    "justArrivedFlag",
    "skipAutoFlagsInput"
  ];

  connect() {
    this.form = this.element
    this.submitButton = this.form.querySelector("button[type='submit'], input[type='submit']")
    this.dirtyFields = new Set()
    this.registeredInputs = new Set()
    this.submitted = false
    this.isMultipleVariantsMode = false
    this.variantCounter = 0
    this.selectors = {
      category: null,
      brands: null,
      collections: null,
      tags: null,
      relatedProducts: null
    }
    this.initialJustArrivedState = this.hasJustArrivedFlagTarget ? this.justArrivedFlagTarget.checked : false

    // Initialize TomSelect instances
    this.initCategorySelect()
    this.initBrandsSelect()
    this.initCollectionsSelect()
    this.initTagsSelect()
    this.initRelatedProductsSelect()

    // Initialize variant mode
    this.initVariantMode()

    // Setup flag change tracking
    this.setupFlagTracking()

    // Setup auto-populate for existing variants
    if (this.hasVariantsListTarget) {
      const existingVariants = this.variantsListTarget.querySelectorAll('[data-controller="nested-form"]')
      existingVariants.forEach(variantForm => {
        this.setupVariantNameAutoPopulate(variantForm)
        this.setupVariantRemovalCheckbox(variantForm)
        this.setupVariantPriceTracking(variantForm)
      })
    }

    // Listen for user interaction to set dirty state
    this.form.querySelectorAll("input, textarea, select").forEach(input => {
      input.addEventListener("input", () => this.markDirty(input))
      input.addEventListener("change", () => this.markDirty(input))
      input.addEventListener("blur", () => this.markDirty(input))
    })

    this.setupProductNameAutoPopulate()

    // Setup Lexical editor listeners
    this.setupLexicalListeners()

    // Disable input wheel events on number fields
    this.form.addEventListener("wheel", (e) => {
      if (e.target.tagName === 'INPUT' && e.target.type === "number") {
        e.target.blur()
      }
    })

    this.form.addEventListener("submit", (e) => {
      this.submitted = true
      const formIsValid = this.validateForm()
      const variantsValid = this.validateAllVariants()

      // Check for any validation errors (form or attributes), but exclude hidden elements
      const allAttributeErrors = this.form.querySelectorAll(".product-form-error:not(:empty)")
      const visibleAttributeErrors = Array.from(allAttributeErrors).filter(errorMessage => {
        // Check if the error message or any of its parents are hidden
        let element = errorMessage
        while (element && element !== this.form) {
          const style = window.getComputedStyle(element)
          if (style.display === 'none' || style.visibility === 'hidden') {
            return false
          }
          element = element.parentElement
        }
        return true
      })
      const hasVisibleAttributeErrors = visibleAttributeErrors.length > 0

      if (!formIsValid || !variantsValid || hasVisibleAttributeErrors) {
        e.preventDefault()
        // Scroll to first error after a brief delay to allow DOM updates
        setTimeout(() => {
          this.scrollToFirstError()
        }, 100)
      } else {
        this.handleFormSubmission()
      }
    })    // Initial validation state
    this.validateForm()
  }

  setupLexicalListeners() {
    const lexicalEditors = this.form.querySelectorAll('[data-controller*="lexical-editor"]')
    lexicalEditors.forEach(editorElement => {
      editorElement.addEventListener('lexical-editor:blur', () => {
        const input = editorElement.querySelector('input[type="hidden"]')
        if (input) {
          this.markDirty(input)
          this.validate()
        }
      })
    })
  }

  // Destroy TomSelect instances
  disconnect() {
    Object.values(this.selectors).forEach(instance => {
      instance?.destroy()
    })
  }

  // Initialize variant mode based on existing variants
  initVariantMode() {
    if (!this.hasVariantsListTarget) return

    const existingVariants = this.variantsListTarget.querySelectorAll('[data-controller="nested-form"]').length

    this.isMultipleVariantsMode = existingVariants > 1

    if (this.hasVariantModeToggleTarget) {
      this.variantModeToggleTarget.checked = this.isMultipleVariantsMode
    }

    this.updateVariantModeDisplay()
    this.updateVariantModeToggleState()
  }

  // Toggle between single and multiple variants mode
  toggleVariantMode(event) {
    this.isMultipleVariantsMode = event.target.checked
    this.updateVariantModeDisplay()
    this.updateVariantModeToggleState()
  }

  // Update UI based on current variant mode
  updateVariantModeDisplay() {
    if (this.hasVariantModeLabelTarget) {
      this.variantModeLabelTarget.textContent = this.isMultipleVariantsMode
        ? "Multiple Variants Mode"
        : "Single Product Mode"
    }

    if (this.hasSingleProductImagesTarget) {
      this.singleProductImagesTarget.style.display = this.isMultipleVariantsMode ? "none" : "block"
    }

    if (this.hasVariantsContainerTarget) {
      this.variantsContainerTarget.style.display = this.isMultipleVariantsMode ? "block" : "none"
    }

    // Trigger auto-resize for all attribute textareas after mode change
    setTimeout(() => {
      this.resizeAllAttributeTextareas()
    }, 100)

    // Enable/disable price inputs based on mode
    if (this.hasOriginalPriceInputTarget) {
      this.originalPriceInputTarget.disabled = this.isMultipleVariantsMode
      this.originalPriceInputTarget.style.opacity = this.isMultipleVariantsMode ? '0.5' : '1'
      this.originalPriceInputTarget.style.cursor = this.isMultipleVariantsMode ? 'not-allowed' : 'text'
    }

    if (this.hasCurrentPriceInputTarget) {
      this.currentPriceInputTarget.disabled = this.isMultipleVariantsMode
      this.currentPriceInputTarget.style.opacity = this.isMultipleVariantsMode ? '0.5' : '1'
      this.currentPriceInputTarget.style.cursor = this.isMultipleVariantsMode ? 'not-allowed' : 'text'
    }

    // If switching to single mode and no variants exist, create a default variant
    if (!this.isMultipleVariantsMode && this.hasVariantsListTarget && this.variantsListTarget.children.length === 0) {
      this.addDefaultVariant()
    }

    // If switching to multiple mode and only have one variant, show it
    if (this.isMultipleVariantsMode && this.hasVariantsListTarget && this.variantsListTarget.children.length <= 1) {
      // Ensure at least one variant is visible
      if (this.variantsListTarget.children.length === 0) {
        this.addVariant()
      }
    }
  }

  // Add a new variant
  addVariant(event) {
    if (event) {
      event.preventDefault()
    }

    if (!this.hasVariantTemplateTarget || !this.hasVariantsListTarget) {
      console.error('Variant template or list target not found')
      return
    }

    const template = this.variantTemplateTarget
    const newVariant = template.content.cloneNode(true)

    // Update the child index to a unique value
    const newIndex = Date.now() + Math.random().toString(36).substr(2, 9)
    const elementsToUpdate = newVariant.querySelectorAll('[id*="NEW_RECORD"], [name*="NEW_RECORD"], [for*="NEW_RECORD"], [data-image-preview-field-base-name-value*="NEW_RECORD"]')

    elementsToUpdate.forEach(element => {
      if (element.id) element.id = element.id.replace("NEW_RECORD", newIndex)
      if (element.name) element.name = element.name.replace("NEW_RECORD", newIndex)
      if (element.htmlFor) element.htmlFor = element.htmlFor.replace("NEW_RECORD", newIndex)
      if (element.dataset.imagePreviewFieldBaseNameValue) {
        element.dataset.imagePreviewFieldBaseNameValue = element.dataset.imagePreviewFieldBaseNameValue.replace("NEW_RECORD", newIndex)
      }
    })

    this.variantsListTarget.appendChild(newVariant)

    // Initialize any controllers in the new variant if the Stimulus application is available
    if (this.application) {
      const newVariantElement = this.variantsListTarget.lastElementChild
      try {
        const imagePreviewController = this.application.getControllerForElementAndIdentifier(newVariantElement, 'image-preview')
        if (imagePreviewController && imagePreviewController.connect) {
          imagePreviewController.connect()
        }
      } catch (error) {
        console.log('Could not initialize image preview controller:', error)
      }

      // Setup auto-populate for the new variant
      this.setupVariantNameAutoPopulate(newVariantElement)
      this.setupVariantRemovalCheckbox(newVariantElement)
      this.setupVariantPriceTracking(newVariantElement)

      // Update variant mode toggle state
      this.updateVariantModeToggleState()

      // Scroll to the newly added variant
      setTimeout(() => {
        newVariantElement.scrollIntoView({
          behavior: "smooth",
          block: "center",
          inline: "nearest"
        })
      }, 100)
    }
  }

  // Add a default variant for single product mode
  addDefaultVariant() {
    this.addVariant()

    if (!this.hasVariantsListTarget) return

    // Set default values for the new variant
    const newVariant = this.variantsListTarget.lastElementChild
    if (!newVariant) return

    const nameInput = newVariant.querySelector('input[name*="[name]"]')
    const skuInput = newVariant.querySelector('input[name*="[sku]"]')

    if (nameInput && !nameInput.value) {
      nameInput.value = "Default"
    }

    if (skuInput && !skuInput.value) {
      const productSku = this.form.querySelector("[name='product[sku]']")?.value
      if (productSku) {
        skuInput.value = productSku + "-DEFAULT"
      }
    }
  }

  // Remove a variant
  removeVariant(event) {
    event.preventDefault()

    const variantForm = event.target.closest('.variant-form-wrapper')
    const variantId = event.target.dataset.variantId

    if (!variantForm || !this.hasVariantsListTarget) return

    const totalVariants = this.variantsListTarget.children.length

    // Don't allow removing the last variant in any mode
    if (totalVariants <= 1) {
      alert("Cannot remove the last variant. A product must have at least one variant.")
      return
    }

    // In multiple variants mode, don't allow removing if it would leave only one
    if (this.isMultipleVariantsMode && totalVariants <= 2) {
      if (!confirm("Removing this variant will leave only one variant. The remaining variant will be converted to default settings. Continue?")) {
        return
      }
    }

    // If this is a persisted variant, we need to mark it for deletion
    if (variantId && variantId !== '') {
      const destroyInput = variantForm.querySelector('input[name*="_destroy"]')
      if (destroyInput) {
        destroyInput.value = 'true'
        variantForm.style.display = 'none'
        return
      }
    }

    // For new variants, just remove the element
    variantForm.remove()

    // Update variant mode toggle state
    this.updateVariantModeToggleState()
    this.updateRemovalCheckboxStates()

    // If we're left with only one variant and in multiple mode,
    // show a message about default conversion
    if (this.isMultipleVariantsMode && this.variantsListTarget.children.length === 1) {
      const remainingVariant = this.variantsListTarget.firstElementChild
      if (remainingVariant) {
        // Add a visual indicator that this will become the default
        const header = remainingVariant.querySelector('h5')
        if (header) {
          header.innerHTML = 'Default Variant (Last Remaining)'
          header.classList.add('text-orange-600')
        }
      }
    }
  }

  // Handle form submission to process single product images
  handleFormSubmission() {
    if (!this.isMultipleVariantsMode) {
      // Strip product_variants_attributes from form data in single product mode
      const variantInputs = this.form.querySelectorAll('[name*="product[product_variants_attributes]"]')
      variantInputs.forEach(input => {
        input.disabled = true
      })
    }
  }

  validate(event) {
    // Validate on input/change
    this.validateForm()
  }

  markDirty(input) {
    if (input && input.name) {
      this.dirtyFields.add(input.name)
    }
  }

  validateForm() {
    let valid = true
    const showErrors = this.submitted

    // Helper to add/remove error border and ARIA
    const setErrorBorder = (input, hasError) => {
      if (!input) return
      if (hasError) {
        input.classList.add("border-red-500")
        input.setAttribute("aria-invalid", "true")
      } else {
        input.classList.remove("border-red-500")
        input.removeAttribute("aria-invalid")
      }
    }

    // Clear all errors and borders
    this.clearErrors()

    // Validate all sections
    valid = this.validateBasicFields(showErrors, setErrorBorder) && valid
    valid = this.validatePriceFields(showErrors, setErrorBorder) && valid
    valid = this.validateContentFields(showErrors, setErrorBorder) && valid
    valid = this.validateSelectFields(showErrors, setErrorBorder) && valid
    valid = this.validateOptionalFields(showErrors, setErrorBorder) && valid

    return valid
  }

  validateBasicFields(showErrors, setErrorBorder) {
    let valid = true

    // name: Required
    const name = this.form.querySelector("[name='product[name]']")
    if (!name.value.trim()) {
      if (showErrors || this.dirtyFields.has(name.name)) this.nameErrorTarget.textContent = "Name is required."
      setErrorBorder(name, showErrors || this.dirtyFields.has(name.name))
      valid = false
    } else {
      setErrorBorder(name, false)
    }

    // sku: Required
    const sku = this.form.querySelector("[name='product[sku]']")
    if (!sku.value.trim()) {
      if (showErrors || this.dirtyFields.has(sku.name)) this.skuErrorTarget.textContent = "SKU is required."
      setErrorBorder(sku, showErrors || this.dirtyFields.has(sku.name))
      valid = false
    } else {
      setErrorBorder(sku, false)
    }

    // slug: Required
    const slug = this.form.querySelector("[name='product[slug]']")
    if (!slug.value.trim()) {
      if (showErrors || this.dirtyFields.has(slug.name)) this.slugErrorTarget.textContent = "Slug is required."
      setErrorBorder(slug, showErrors || this.dirtyFields.has(slug.name))
      valid = false
    } else {
      setErrorBorder(slug, false)
    }

    // status: Required, must be one of: active, inactive, discontinued
    const status = this.form.querySelector("[name='product[status]']")
    if (!status.value || !STATUS_VALUES.includes(status.value)) {
      if (showErrors || this.dirtyFields.has(status.name)) this.statusErrorTarget.textContent = "Status is required and must be valid."
      setErrorBorder(status, showErrors || this.dirtyFields.has(status.name))
      valid = false
    } else {
      setErrorBorder(status, false)
    }

    return valid
  }

  validatePriceFields(showErrors, setErrorBorder) {
    let valid = true

    // current_price: Optional in single product mode, number ≥ 0
    const currentPrice = this.form.querySelector("[name='product[current_price]']")
    if (!this.isMultipleVariantsMode && currentPrice && currentPrice.value.trim() && (isNaN(currentPrice.value) || Number(currentPrice.value) < 0)) {
      if (showErrors || this.dirtyFields.has(currentPrice.name)) this.currentPriceErrorTarget.textContent = "Cost Price must be a number ≥ 0."
      setErrorBorder(currentPrice, showErrors || this.dirtyFields.has(currentPrice.name))
      valid = false
    } else if (currentPrice) {
      setErrorBorder(currentPrice, false)
    }

    return valid
  }

  validateContentFields(showErrors, setErrorBorder) {
    let valid = true

    // meta_title: Optional, max 255 chars
    const metaTitle = this.form.querySelector("[name='product[meta_title]']")
    if (metaTitle && metaTitle.value.length > 255) {
      if (showErrors || this.dirtyFields.has(metaTitle.name)) this.metaTitleErrorTarget.textContent = "Meta title must be 255 characters or less."
      setErrorBorder(metaTitle, showErrors || this.dirtyFields.has(metaTitle.name))
      valid = false
    } else if (metaTitle) {
      setErrorBorder(metaTitle, false)
    }

    // meta_description: Optional, max 500 chars
    const metaDescription = this.form.querySelector("[name='product[meta_description]']")
    if (metaDescription && metaDescription.value.length > 500) {
      if (showErrors || this.dirtyFields.has(metaDescription.name)) this.metaDescriptionErrorTarget.textContent = "Meta description must be 500 characters or less."
      setErrorBorder(metaDescription, showErrors || this.dirtyFields.has(metaDescription.name))
      valid = false
    } else if (metaDescription) {
      setErrorBorder(metaDescription, false)
    }

    // description: Lexical field validation
    const description = this.form.querySelector("[name='product[description]']")
    if (description) {
      const lexicalController = this.application.getControllerForElementAndIdentifier(
        description.closest('[data-controller*="lexical-editor"]'),
        "lexical-editor"
      )

      if (lexicalController && (showErrors || this.dirtyFields.has(description.name))) {
        if (lexicalController.isEmpty()) {
          this.descriptionErrorTarget.textContent = "Description cannot be blank."
          this.setLexicalErrorBorder(description, true)
          valid = false
        } else {
          this.setLexicalErrorBorder(description, false)
        }
      }
    }

    return valid
  }

  validateSelectFields(showErrors, setErrorBorder) {
    let valid = true

    // category: Required validation
    const categorySelect = this.form.querySelector("[name='product[category_id]']")
    if (categorySelect) {
      if (!categorySelect.value || categorySelect.value === "") {
        if (showErrors || this.dirtyFields.has(categorySelect.name)) {
          if (this.hasCategoryErrorTarget) this.categoryErrorTarget.textContent = "Category is required."
          this.setTomSelectErrorBorder(categorySelect, true)
          valid = false
        }
      } else if (isNaN(categorySelect.value)) {
        if (showErrors || this.dirtyFields.has(categorySelect.name)) {
          if (this.hasCategoryErrorTarget) this.categoryErrorTarget.textContent = "Please select a valid category."
          this.setTomSelectErrorBorder(categorySelect, true)
          valid = false
        }
      } else {
        this.setTomSelectErrorBorder(categorySelect, false)
      }
    }

    // brands: Required validation - at least one brand must be selected
    const brandsSelect = this.form.querySelector("[name='product[brand_ids][]'], [name*='brand_ids']")
    if (brandsSelect) {
      // Check if any brands are selected
      const selectedBrands = this.form.querySelectorAll("[name='product[brand_ids][]']:checked, select[name*='brand_ids'] option:checked")

      // For TomSelect, check the control's selected items
      let hasSelectedBrands = selectedBrands.length > 0

      // If using TomSelect, check the TomSelect instance for selected items
      const tomSelectWrapper = brandsSelect.parentElement.querySelector('.ts-control')
      if (tomSelectWrapper) {
        const tomSelectItems = tomSelectWrapper.querySelectorAll('.item')
        hasSelectedBrands = tomSelectItems.length > 0
      }

      if (!hasSelectedBrands) {
        if (showErrors || this.dirtyFields.has(brandsSelect.name)) {
          if (this.hasBrandsErrorTarget) this.brandsErrorTarget.textContent = "At least one brand is required."
          this.setTomSelectErrorBorder(brandsSelect, true)
          valid = false
        }
      } else {
        this.setTomSelectErrorBorder(brandsSelect, false)
      }
    }

    // collections: Optional validation
    const collectionsSelect = this.form.querySelector("[name='product[product_collection_ids][]'], [name*='product_collection_ids']")
    if (collectionsSelect) {
      // Collections are optional, but if selected, should be valid
      this.setTomSelectErrorBorder(collectionsSelect, false)
    }

    // tags: Optional validation
    const tagsSelect = this.form.querySelector("[name='product[product_tag_ids][]'], [name*='product_tag_ids']")
    if (tagsSelect) {
      // Tags are optional, but if selected, should be valid
      this.setTomSelectErrorBorder(tagsSelect, false)
    }

    // related_products: Optional validation
    const relatedProductsSelect = this.form.querySelector("[name='product[related_product_ids][]'], [name*='related_product_ids']")
    if (relatedProductsSelect) {
      // Related products are optional, but if selected, should be valid
      this.setTomSelectErrorBorder(relatedProductsSelect, false)
    }

    return valid
  }

  validateOptionalFields(showErrors, setErrorBorder) {
    let valid = true

    // weight: Optional, number ≥ 0
    const weight = this.form.querySelector("[name='product[weight]']")
    if (weight && weight.value.trim() && (isNaN(weight.value) || Number(weight.value) < 0)) {
      if (showErrors || this.dirtyFields.has(weight.name)) this.weightErrorTarget.textContent = "Weight must be a number ≥ 0."
      setErrorBorder(weight, showErrors || this.dirtyFields.has(weight.name))
      valid = false
    } else if (weight) {
      setErrorBorder(weight, false)
    }

    // sort_order: Optional, must be integer if present
    const sortOrder = this.form.querySelector("[name='product[sort_order]']")
    if (sortOrder && sortOrder.value.trim() && !Number.isInteger(Number(sortOrder.value))) {
      if (showErrors || this.dirtyFields.has(sortOrder.name)) this.sortOrderErrorTarget.textContent = "Sort Order must be an integer."
      setErrorBorder(sortOrder, showErrors || this.dirtyFields.has(sortOrder.name))
      valid = false
    } else if (sortOrder) {
      setErrorBorder(sortOrder, false)
    }

    // flags: If present, all values must be from allowed list
    const flagInputs = this.form.querySelectorAll("input[name='product[flags][]']:checked")
    if (flagInputs.length > 0) {
      for (const input of flagInputs) {
        if (!FLAG_VALUES.includes(input.value)) {
          if (showErrors || this.dirtyFields.has(input.name)) this.showFieldError(input, "Invalid flag selected.")
          setErrorBorder(input, showErrors || this.dirtyFields.has(input.name))
          valid = false
        } else {
          setErrorBorder(input, false)
        }
      }
    }

    return valid
  }

  // Helper method to resize all attribute textareas in visible forms
  resizeAllAttributeTextareas() {
    // Find all variant attribute controllers
    const variantAttrElements = this.form.querySelectorAll('[data-controller*="variant-attributes"]')
    variantAttrElements.forEach(element => {
      const controller = this.application.getControllerForElementAndIdentifier(element, 'variant-attributes')
      if (controller && controller.autoResizeAllTextareas) {
        controller.autoResizeAllTextareas()
      }
    })
  }

  // Add visual feedback for validation process
  showValidationFeedback() {
    // Add a temporary indicator that validation is checking
    const indicator = document.createElement('div')
    indicator.className = 'validation-scroll-indicator'
    indicator.textContent = 'Checking form...'
    document.body.appendChild(indicator)

    setTimeout(() => {
      indicator.remove()
    }, 2000)
  }

  scrollToFirstError() {
    // Find all error message containers that have content - includes both form errors and attribute errors
    const allErrorMessages = this.form.querySelectorAll(".product-form-error:not(:empty)")

    // Filter out error messages that are in hidden containers
    const visibleErrorMessages = Array.from(allErrorMessages).filter(errorMessage => {
      // Check if the error message or any of its parents are hidden
      let element = errorMessage
      while (element && element !== this.form) {
        const style = window.getComputedStyle(element)
        if (style.display === 'none' || style.visibility === 'hidden') {
          return false
        }
        element = element.parentElement
      }
      return true
    })

    if (visibleErrorMessages.length > 0) {
      const firstErrorMessage = visibleErrorMessages[0]
      console.log(`Scrolling to error message:`, firstErrorMessage.textContent, firstErrorMessage)

      // Scroll the error message into view
      firstErrorMessage.scrollIntoView({
        behavior: "smooth",
        block: "center",
        inline: "nearest"
      })
    }
  }

  clearErrors() {
    // Clear all error targets
    if (this.hasNameErrorTarget) this.nameErrorTarget.textContent = ""
    if (this.hasSkuErrorTarget) this.skuErrorTarget.textContent = ""
    if (this.hasSlugErrorTarget) this.slugErrorTarget.textContent = ""
    if (this.hasOriginalPriceErrorTarget) this.originalPriceErrorTarget.textContent = ""
    if (this.hasCurrentPriceErrorTarget) this.currentPriceErrorTarget.textContent = ""
    if (this.hasStatusErrorTarget) this.statusErrorTarget.textContent = ""
    if (this.hasShortDescriptionErrorTarget) this.shortDescriptionErrorTarget.textContent = ""
    if (this.hasMetaTitleErrorTarget) this.metaTitleErrorTarget.textContent = ""
    if (this.hasMetaDescriptionErrorTarget) this.metaDescriptionErrorTarget.textContent = ""
    if (this.hasWeightErrorTarget) this.weightErrorTarget.textContent = ""
    if (this.hasDescriptionErrorTarget) this.descriptionErrorTarget.textContent = ""
    if (this.hasSortOrderErrorTarget) this.sortOrderErrorTarget.textContent = ""
    if (this.hasCategoryErrorTarget) this.categoryErrorTarget.textContent = ""
    if (this.hasBrandsErrorTarget) this.brandsErrorTarget.textContent = ""
    if (this.hasCollectionsErrorTarget) this.collectionsErrorTarget.textContent = ""
    if (this.hasTagsErrorTarget) this.tagsErrorTarget.textContent = ""
    if (this.hasFeaturedErrorTarget) this.featuredErrorTarget.textContent = ""
    if (this.hasFlagsErrorTarget) this.flagsErrorTarget.textContent = ""

    // Remove all error borders from regular inputs
    this.form.querySelectorAll(".border-red-500").forEach(el => {
      el.classList.remove("border-red-500")
      el.removeAttribute("aria-invalid")
    })

    // Remove inline field-level errors
    this.form.querySelectorAll(".product-form-error-inline").forEach(el => el.textContent = "")
  }

  showFieldError(input, message) {
    // Try to find or create an inline error element after the input
    let errorEl = input.parentNode.querySelector(".product-form-error-inline")
    if (!errorEl) {
      errorEl = document.createElement("div")
      errorEl.className = "text-red-600 text-xs mt-1 product-form-error-inline"
      input.parentNode.appendChild(errorEl)
    }
    errorEl.textContent = message
  }

  // Helper method to set error borders on Lexical editors
  setLexicalErrorBorder(textarea, hasError) {
    if (!textarea) return

    const editorContainer = textarea.closest('[data-controller*="lexical-editor"]')
    if (editorContainer) {
      const editorDiv = editorContainer.querySelector('[data-lexical-editor-target="editor"]')
      if (editorDiv) {
        if (hasError) {
          editorDiv.classList.add("border-red-500", "focus:ring-red-500")
          editorDiv.classList.remove("border-gray-300", "focus:ring-blue-500")
          textarea.setAttribute("aria-invalid", "true")
        } else {
          editorDiv.classList.remove("border-red-500", "focus:ring-red-500")
          editorDiv.classList.add("border-gray-300", "focus:ring-blue-500")
          textarea.removeAttribute("aria-invalid")
        }
      }
    }
  }

  // Helper method to set error borders on TomSelect elements
  setTomSelectErrorBorder(select, hasError) {
    if (!select) return

    // Find the TomSelect wrapper
    const tomSelectWrapper = select.parentElement.querySelector('.ts-control')

    if (tomSelectWrapper) {
      if (hasError) {
        tomSelectWrapper.classList.add("border-red-500")
        tomSelectWrapper.setAttribute("aria-invalid", "true")
      } else {
        tomSelectWrapper.classList.remove("border-red-500")
        tomSelectWrapper.removeAttribute("aria-invalid")
      }
    } else {
      // Fallback to regular select if TomSelect not initialized yet
      if (hasError) {
        select.classList.add("border-red-500")
        select.setAttribute("aria-invalid", "true")
      } else {
        select.classList.remove("border-red-500")
        select.removeAttribute("aria-invalid")
      }
    }
  }

  // TomSelect initialization methods
  initCategorySelect() {
    if (!this.hasCategorySelectTarget || this.categorySelectTarget.classList.contains('tomselected')) return

    this.selectors.category = new TomSelect(this.categorySelectTarget, {
      persist: false,
      valueField: 'id',
      labelField: 'title',
      searchField: 'title',
      preload: 'focus',
      load: function (query, callback) {
        const url = query ? `/admin/selectors/categories?q=${encodeURIComponent(query)}` : '/admin/selectors/categories'
        fetch(url)
          .then(response => response.json())
          .then(callback)
          .catch((err) => {
            console.error('Error fetching categories:', err)
            callback()
          })
      }
    })
  }

  initBrandsSelect() {
    if (!this.hasBrandsSelectTarget || this.brandsSelectTarget.classList.contains('tomselected')) return

    this.selectors.brands = new TomSelect(this.brandsSelectTarget, {
      persist: false,
      valueField: 'id',
      labelField: 'name',
      searchField: 'name',
      preload: 'focus',
      plugins: ['remove_button'],
      load: function (query, callback) {
        const url = query ? `/admin/selectors/brands?q=${encodeURIComponent(query)}` : '/admin/selectors/brands'
        fetch(url)
          .then(response => response.json())
          .then(callback)
          .catch(() => callback())
      }
    })
  }

  initCollectionsSelect() {
    if (!this.hasCollectionsSelectTarget || this.collectionsSelectTarget.classList.contains('tomselected')) return

    this.selectors.collections = new TomSelect(this.collectionsSelectTarget, {
      persist: false,
      valueField: 'id',
      labelField: 'name',
      searchField: 'name',
      preload: 'focus',
      plugins: ['remove_button'],
      load: function (query, callback) {
        const url = query ? `/admin/selectors/product_collections?q=${encodeURIComponent(query)}` : '/admin/selectors/product_collections'
        fetch(url)
          .then(response => response.json())
          .then(callback)
          .catch(() => callback())
      }
    })
  }

  initTagsSelect() {
    if (!this.hasTagsSelectTarget || this.tagsSelectTarget.classList.contains('tomselected')) return

    this.selectors.tags = new TomSelect(this.tagsSelectTarget, {
      persist: false,
      plugins: ['remove_button'],
      create: true
    })
  }

  initRelatedProductsSelect() {
    if (!this.hasRelatedProductsSelectTarget || this.relatedProductsSelectTarget.classList.contains('tomselected')) return

    this.selectors.relatedProducts = new TomSelect(this.relatedProductsSelectTarget, {
      persist: false,
      valueField: 'id',
      labelField: 'name',
      searchField: ['name', 'sku'],
      preload: 'focus',
      plugins: ['remove_button'],
      render: {
        option: (item, escape) => {
          return `<div class="py-2">
            <div class="font-medium">${escape(item.name)}</div>
            <div class="text-xs text-gray-500">SKU: ${escape(item.sku)}</div>
          </div>`
        },
        item: (item, escape) => {
          return `<div>${escape(item.name)}</div>`
        }
      },
      load: function (query, callback) {
        const url = query ? `/admin/selectors/products?q=${encodeURIComponent(query)}` : '/admin/selectors/products'
        fetch(url)
          .then(response => response.json())
          .then(callback)
          .catch(() => callback())
      }
    })
  }

  deleteVariant(event) {
    const button = event.currentTarget
    const url = button.getAttribute("data-variant-url")
    const confirmMessage = button.getAttribute("data-confirm-message") || "Are you sure?"
    if (!window.confirm(confirmMessage)) return

    // CSRF token from meta tag
    const token = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content")
    fetch(url, {
      method: "DELETE",
      headers: {
        "X-CSRF-Token": token,
        "Accept": "application/json"
      },
      credentials: "same-origin"
    }).then(response => {
      if (response.ok) {
        window.scrollTo({ top: 0, behavior: "smooth" })
        window.location.reload()
      } else {
        alert("Failed to delete variant.")
      }
    }).catch(() => {
      alert("Failed to delete variant.")
    })
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

  setupProductNameAutoPopulate() {
    const nameInput = this.form.querySelector('[name="product[name]"]')
    const skuInput = this.form.querySelector('[name="product[sku]"]')
    const slugInput = this.form.querySelector('[name="product[slug]"]')

    if (!nameInput) return

    nameInput.addEventListener('blur', () => {
      const productName = nameInput.value.trim()
      if (!productName) return

      const slug = this.sanitizeSlug(productName)

      if (slug) {
        if (slugInput && !slugInput.value.trim()) {
          slugInput.value = slug
        }

        if (skuInput && !skuInput.value.trim()) {
          skuInput.value = slug.toUpperCase()
        }
      }
    })
  }

  setupVariantNameAutoPopulate(variantForm) {
    const nameInput = variantForm.querySelector('input[name*="[name]"]')
    const skuInput = variantForm.querySelector('input[name*="[sku]"]')
    const slugInput = variantForm.querySelector('input[name*="[slug]"]')

    if (!nameInput || !skuInput || !slugInput) return

    nameInput.addEventListener('blur', () => {
      const variantName = nameInput.value.trim()
      if (!variantName) return

      const variantSlug = this.sanitizeSlug(variantName)

      if (variantSlug) {
        if (!slugInput.value.trim()) {
          slugInput.value = variantSlug
        }

        if (!skuInput.value.trim()) {
          skuInput.value = variantSlug.toUpperCase()
        }
      }
    })
  }

  setupVariantRemovalCheckbox(variantForm) {
    const destroyCheckbox = variantForm.querySelector('input[type="checkbox"][name*="[_destroy]"]')
    if (!destroyCheckbox) return

    destroyCheckbox.addEventListener('change', () => {
      this.updateRemovalCheckboxStates()
      this.updateVariantModeToggleState()
    })
  }

  updateRemovalCheckboxStates() {
    if (!this.hasVariantsListTarget) return

    const allVariantForms = this.variantsListTarget.querySelectorAll('[data-controller="nested-form"]')
    const destroyCheckboxes = Array.from(allVariantForms).map(form => {
      return form.querySelector('input[type="checkbox"][name*="[_destroy]"]')
    }).filter(checkbox => checkbox !== null)

    const checkedCount = destroyCheckboxes.filter(cb => cb.checked).length
    const totalCount = destroyCheckboxes.length

    destroyCheckboxes.forEach(checkbox => {
      if (checkedCount === totalCount - 1 && !checkbox.checked) {
        checkbox.disabled = true
        const label = checkbox.closest('label') || checkbox.parentElement
        if (label) {
          label.style.opacity = '0.5'
          label.style.cursor = 'not-allowed'
          label.title = 'Cannot remove the last variant'
        }
      } else {
        checkbox.disabled = false
        const label = checkbox.closest('label') || checkbox.parentElement
        if (label) {
          label.style.opacity = '1'
          label.style.cursor = 'pointer'
          label.title = ''
        }
      }
    })
  }

  updateVariantModeToggleState() {
    if (!this.hasVariantModeToggleTarget || !this.hasVariantsListTarget) return

    const allVariantForms = this.variantsListTarget.querySelectorAll('[data-controller="nested-form"]')
    let activeVariantsCount = 0

    allVariantForms.forEach(form => {
      const destroyCheckbox = form.querySelector('input[type="checkbox"][name*="[_destroy]"]')
      if (!destroyCheckbox || !destroyCheckbox.checked) {
        activeVariantsCount++
      }
    })

    if (activeVariantsCount > 1) {
      this.variantModeToggleTarget.disabled = true
      this.variantModeToggleTarget.style.opacity = '0.5'
      this.variantModeToggleTarget.style.cursor = 'not-allowed'
      const toggleLabel = this.variantModeToggleTarget.closest('label')
      if (toggleLabel) {
        toggleLabel.title = 'Cannot change mode when there are multiple variants'
      }
    } else {
      this.variantModeToggleTarget.disabled = false
      this.variantModeToggleTarget.style.opacity = '1'
      this.variantModeToggleTarget.style.cursor = 'pointer'
      const toggleLabel = this.variantModeToggleTarget.closest('label')
      if (toggleLabel) {
        toggleLabel.title = ''
      }
    }
  }

  validateAllVariants() {
    if (!this.hasVariantsListTarget || !this.isMultipleVariantsMode) return true

    let allValid = true
    const variantForms = this.variantsListTarget.querySelectorAll('[data-controller="nested-form"]')

    variantForms.forEach(variantForm => {
      // Skip hidden variants (marked for deletion)
      if (variantForm.style.display === 'none') return

      const destroyInput = variantForm.querySelector('input[name*="[_destroy]"]')
      if (destroyInput && destroyInput.value === 'true') return

      const isValid = this.validateVariant(variantForm)
      if (!isValid) allValid = false
    })

    return allValid
  }

  validateVariant(variantForm) {
    let valid = true
    const showErrors = this.submitted

    // Helper to add/remove error border and display error message
    const setVariantError = (input, errorMessage) => {
      if (!input) return

      // Find or create error message element
      let errorEl = input.parentElement.querySelector('.variant-error-message')
      if (!errorEl) {
        errorEl = document.createElement('div')
        errorEl.className = 'text-red-600 text-xs mt-1 variant-error-message product-form-error'
        input.parentElement.appendChild(errorEl)
      }

      if (errorMessage) {
        input.classList.add('border-red-500')
        input.setAttribute('aria-invalid', 'true')
        errorEl.textContent = errorMessage
      } else {
        input.classList.remove('border-red-500')
        input.removeAttribute('aria-invalid')
        errorEl.textContent = ''
      }
    }

    // Validate name (required)
    const nameInput = variantForm.querySelector('input[name*="[name]"]')
    if (nameInput) {
      if (!nameInput.value.trim()) {
        if (showErrors) setVariantError(nameInput, 'Variant name is required')
        valid = false
      } else {
        setVariantError(nameInput, '')
      }
    }

    // Validate SKU (required)
    const skuInput = variantForm.querySelector('input[name*="[sku]"]')
    if (skuInput) {
      if (!skuInput.value.trim()) {
        if (showErrors) setVariantError(skuInput, 'Variant SKU is required')
        valid = false
      } else {
        setVariantError(skuInput, '')
      }
    }

    // Validate slug (required)
    const slugInput = variantForm.querySelector('input[name*="[slug]"]')
    if (slugInput) {
      if (!slugInput.value.trim()) {
        if (showErrors) setVariantError(slugInput, 'Variant slug is required')
        valid = false
      } else {
        setVariantError(slugInput, '')
      }
    }

    // Validate status (required)
    const statusSelect = variantForm.querySelector('select[name*="[status]"]')
    if (statusSelect) {
      if (!statusSelect.value || statusSelect.value === '') {
        if (showErrors) setVariantError(statusSelect, 'Variant status is required')
        valid = false
      } else {
        setVariantError(statusSelect, '')
      }
    }

    return valid
  }

  setupFlagTracking() {
    if (this.hasJustArrivedFlagTarget) {
      this.justArrivedFlagTarget.addEventListener('change', (e) => {
        if (e.target.checked && this.hasArriveSoonFlagTarget && this.arriveSoonFlagTarget.checked) {
          this.arriveSoonFlagTarget.checked = false
        }

        if (!e.target.checked && this.initialJustArrivedState) {
          if (this.hasSkipAutoFlagsInputTarget) {
            this.skipAutoFlagsInputTarget.value = 'true'
          }
        }
      })
    }

    if (this.hasArriveSoonFlagTarget) {
      this.arriveSoonFlagTarget.addEventListener('change', (e) => {
        if (e.target.checked && this.hasJustArrivedFlagTarget && this.justArrivedFlagTarget.checked) {
          this.justArrivedFlagTarget.checked = false
        }
      })
    }
  }

  setupVariantPriceTracking(variantForm) {
    const originalPriceInput = variantForm.querySelector('input[name*="[original_price]"]')
    const currentPriceInput = variantForm.querySelector('input[name*="[current_price]"]')

    if (originalPriceInput) {
      originalPriceInput.addEventListener('input', () => this.checkPriceChanges())
    }
    if (currentPriceInput) {
      currentPriceInput.addEventListener('input', () => this.checkPriceChanges())
    }
  }

  checkPriceChanges() {
    if (!this.hasSkipAutoFlagsInputTarget) return

    const skipFlagsValue = this.skipAutoFlagsInputTarget.value
    if (skipFlagsValue === 'true') {
      this.skipAutoFlagsInputTarget.value = 'false'
    }
  }
}
