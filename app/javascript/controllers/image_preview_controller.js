import { Controller } from "@hotwired/stimulus"
import Sortable from 'sortablejs'

/*
  Defensive improvements:
  - Robust extraction of image URL from clicked element (data-* attributes, img[src], data-src, style background-image, <picture> fallback)
  - Graceful fallback to global modal/image targets if the controller instance does not have targets
  - Lightweight delegated click handler to support pages where a data-controller="image-preview" wrapper is not present
*/

function extractImageUrlFromElement(el) {
  if (!el) return null

  // 1) Explicit Stimulus value attribute: data-image-preview-image-url-value
  if (el.dataset && el.dataset.imagePreviewImageUrlValue) return el.dataset.imagePreviewImageUrlValue

  // 2) Common dataset attributes
  if (el.dataset && el.dataset.imageUrl) return el.dataset.imageUrl
  if (el.dataset && el.dataset.url) return el.dataset.url
  if (el.dataset && el.dataset.src) return el.dataset.src

  // 3) HTML attributes
  const attrCandidates = ["data-image-url", "data-url", "data-src", "data-image"]
  for (const a of attrCandidates) {
    const v = el.getAttribute(a)
    if (v) return v
  }

  // 4) If element is an <img>
  if (el.tagName && el.tagName.toLowerCase() === "img") {
    if (el.src) return el.src
    if (el.dataset && el.dataset.src) return el.dataset.src
  }

  // 5) Look for nested <picture> or <img>
  const nestedImg = el.querySelector && (el.querySelector("picture img") || el.querySelector("img"))
  if (nestedImg) {
    if (nestedImg.src) return nestedImg.src
    if (nestedImg.dataset && nestedImg.dataset.src) return nestedImg.dataset.src
  }

  // 6) CSS background-image
  try {
    const bg = getComputedStyle(el).backgroundImage
    if (bg && bg !== "none") {
      // backgroundImage: url("...") or url(...)
      const m = bg.match(/url\((['"]?)(.*?)\1\)/)
      if (m && m[2]) return m[2]
    }
  } catch (err) {
    // ignore
  }

  return null
}

export default class extends Controller {
  static targets = ["input", "previews", "modal", "image"];
  static values = {
    existingImages: Array,
    imageUrl: String,
    removeParamName: { type: String, default: "images_to_remove[]" },
    fieldBaseName: { type: String, default: "" },
    type: { type: String, default: "single" }
  }

  static formControllers = new Map()

  static registerFormSubmitHandler(form) {
    if (form.dataset.imagePreviewHandlerRegistered) return
    form.dataset.imagePreviewHandlerRegistered = 'true'
    form.addEventListener('submit', (event) => {
      // Remove any previously injected position inputs (but keep _destroy inputs)
      const oldPositionInputs = form.querySelectorAll('input[name*="[product_images_attributes]"][name*="[position]"], input[name*="[product_images_positions]"]')
      oldPositionInputs.forEach(input => input.remove())

      const controllers = this.formControllers.get(form) || []
      controllers.forEach(controller => {
        controller.handleFormSubmit(event)
      })
    })
  }

  static registerController(form, controller) {
    if (!this.formControllers.has(form)) {
      this.formControllers.set(form, [])
      this.registerFormSubmitHandler(form)
    }
    const controllers = this.formControllers.get(form)
    if (!controllers.includes(controller)) {
      controllers.push(controller)
    }
  }

  static unregisterController(form, controller) {
    if (!this.formControllers.has(form)) return
    const controllers = this.formControllers.get(form)
    const index = controllers.indexOf(controller)
    if (index > -1) {
      controllers.splice(index, 1)
    }
    if (controllers.length === 0) {
      this.formControllers.delete(form)
    }
  }

  // Helper to generate unique keys
  generateKey() {
    return 'item-' + Date.now() + '-' + Math.random().toString(36).substr(2, 9)
  }

  connect() {
    const variantCheckbox = document.querySelector('input[data-product-form-target="variantModeToggle"]')
    this.variantMode = variantCheckbox ? variantCheckbox.checked : false
    console.log("ImagePreviewController connected. Variant mode:", this.variantMode, "Type value:", this.typeValue)
    // Unified list of items with unique keys for reconciliation
    this.items = (this.existingImagesValue || []).map(img => ({
      type: 'existing',
      key: this.generateKey(),
      ...img
    }))

    this.renderPreviews()
    // Bind and register Escape key handler
    this.escapeHandler = this.handleEscape.bind(this)
    document.addEventListener("keydown", this.escapeHandler)

    // Register this controller instance with its form
    const form = this.element.closest('form')
    if (form) {
      this.constructor.registerController(form, this)
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.escapeHandler)
    if (this.sortable) this.sortable.destroy()

    const form = this.element.closest('form')
    if (form) {
      this.constructor.unregisterController(form, this)
    }
  }

  handleEscape(event) {
    if (!event) return
    const key = event.key || event.keyIdentifier
    if (key === "Escape" || key === "Esc") {
      if (this.hasModalTarget && !this.modalTarget.classList.contains("hidden")) {
        this.close()
      } else {
        // Also try to close any global fallback modal if present
        const globalModal = document.querySelector('[data-image-preview-target="modal"].__image-preview-fallback')
        if (globalModal) globalModal.classList.add("hidden")
      }
    }
  }

  open(event) {
    event.preventDefault()
    const button = event.currentTarget
    // Attempt robust extraction from clicked element first
    const extracted = extractImageUrlFromElement(button)
    const imageUrl = extracted || button.dataset.imagePreviewImageUrlValue || this.imageUrlValue
    // Prefer instance targets but fallback to global ones if missing
    const imageTargetEl = this.hasImageTarget ? this.imageTarget : document.querySelector('[data-image-preview-target="image"]')
    const modalTargetEl = this.hasModalTarget ? this.modalTarget : document.querySelector('[data-image-preview-target="modal"]')

    if (imageUrl && imageTargetEl) {
      // If the URL looks like an SVG, fetch it with a cache-bust and create an object URL
      // so we can force the correct MIME type even when the server returns wrong headers
      const isSvg = /\.svg(\?|$)/i.test(imageUrl)
      if (isSvg) {
        const cacheBusted = imageUrl + (imageUrl.includes('?') ? '&' : '?') + 't=' + Date.now()
        fetch(cacheBusted, { cache: 'no-store' })
          .then(res => res.blob())
          .then(raw => {
            let svgBlob = raw
            try {
              if (!svgBlob.type || svgBlob.type === 'application/octet-stream') {
                svgBlob = svgBlob.slice(0, svgBlob.size, 'image/svg+xml')
              }
            } catch (e) {
              // ignore slicing errors
            }

            const objUrl = URL.createObjectURL(svgBlob)
            // store so we can revoke later
            this._currentObjectUrl = objUrl
            imageTargetEl.src = objUrl
            imageTargetEl.alt = button.dataset.imageAlt || "Full size image"
            if (modalTargetEl) this.showModal(modalTargetEl)
          })
          .catch(() => {
            // fallback to direct URL if fetch fails
            imageTargetEl.src = imageUrl
            imageTargetEl.alt = button.dataset.imageAlt || "Full size image"
            if (modalTargetEl) this.showModal(modalTargetEl)
          })
      } else {
        imageTargetEl.src = imageUrl
        imageTargetEl.alt = button.dataset.imageAlt || "Full size image"
        if (modalTargetEl) {
          this.showModal(modalTargetEl)
        }
      }
    }
  }

  close(event) {
    if (event) event.preventDefault()
    if (this.hasModalTarget) {
      this.hideModal(this.modalTarget)
    } else {
      const globalModal = document.querySelector('[data-image-preview-target="modal"].__image-preview-fallback')
      if (globalModal) {
        this.hideModal(globalModal)
      }
    }
  }

  showModal(modal) {
    modal.classList.remove("hidden")
    modal.setAttribute("data-modal-open", "true")
    modal.setAttribute("aria-hidden", "false")
    modal.tabIndex = -1
    modal.focus()
  }

  hideModal(modal) {
    modal.classList.add("hidden")
    modal.setAttribute("data-modal-open", "false")
    modal.setAttribute("aria-hidden", "true")
    try {
      // Revoke any object URL we created for SVG previews
      if (this._currentObjectUrl) {
        try { URL.revokeObjectURL(this._currentObjectUrl) } catch (e) { }
        this._currentObjectUrl = null
      }
      // Clear the image src to avoid stale display
      const imageEl = this.hasImageTarget ? this.imageTarget : document.querySelector('[data-image-preview-target="image"]')
      if (imageEl) imageEl.src = ""
    } catch (e) {
      // ignore cleanup errors
    }
  }

  // Close modal when clicking on backdrop
  backdropClose(event) {
    if (event.target === this.modalTarget) {
      this.close(event)
    }
  }

  preview() {
    const files = Array.from(this.inputTarget.files || [])
    if (files.length === 0) return

    if (!this.inputTarget.multiple) {
      const file = files[0]
      // Mark existing for removal
      this.items.forEach(item => {
        if (item.type === 'existing') this.markExistingForRemoval(item.id)
      })
      // Replace items
      this.items = [{ type: 'new', key: this.generateKey(), file }]
    } else {
      // Append unique files
      files.forEach(file => {
        const exists = this.items.some(item =>
          item.type === 'new' &&
          item.file.name === file.name &&
          item.file.size === file.size &&
          item.file.lastModified === file.lastModified
        )
        if (!exists) {
          this.items.push({ type: 'new', key: this.generateKey(), file })
        }
      })
    }

    this.syncInputFiles()
    this.renderPreviews()
  }

  syncInputFiles() {
    const dt = new DataTransfer()
    this.items.forEach(item => {
      if (item.type === 'new') {
        dt.items.add(item.file)
      }
    })
    this.inputTarget.files = dt.files
  }

  renderPreviews() {
    // Reconciliation: Update DOM to match this.items without clearing everything

    // 1. Mark current DOM elements
    const validKeys = new Set(this.items.map(i => i.key))
    const existingWrappers = Array.from(this.previewsTarget.children)

    // 2. Remove elements that are no longer in items
    existingWrappers.forEach(el => {
      if (!validKeys.has(el.dataset.key)) el.remove()
    })

    // 3. Create or updating elements in order
    this.items.forEach((item) => {
      let wrapper = this.previewsTarget.querySelector(`[data-key="${item.key}"]`)

      if (!wrapper) {
        wrapper = this.createPreviewElement(item)
        this.previewsTarget.appendChild(wrapper)
      }

      // Ensure DOM order matches array order
      this.previewsTarget.appendChild(wrapper)
    })

    if (!this.sortable) {
      this.initSortable()
    }
  }

  createPreviewElement(item) {
    const wrapper = document.createElement("div")
    wrapper.className = "relative flex flex-col items-center gap-2"
    wrapper.setAttribute("data-key", item.key)

    const img = document.createElement("img")
    img.className = "size-24 object-cover rounded border border-gray-300"

    if (item.type === 'existing') {
      img.src = item.url
    } else {
      const reader = new FileReader()
      reader.onload = e => img.src = e.target.result
      reader.readAsDataURL(item.file)
    }

    const removeBtn = document.createElement("button")
    removeBtn.type = "button"
    removeBtn.innerText = "✕"
    removeBtn.className = "absolute top-2 right-1.5 bg-white bg-opacity-80 rounded-full px-1.5 py-0.5 text-xs text-red-600 border border-red-200 hover:bg-red-100"
    removeBtn.setAttribute("aria-label", "Remove image")
    // Use data access to find item instead of closure index which goes stale
    removeBtn.addEventListener("click", (e) => this.remove(e))

    const reorderHandle = document.createElement("button")
    reorderHandle.type = "button"
    reorderHandle.innerText = "⇅"
    reorderHandle.className = "image-preview-handle absolute top-2 left-1.5 bg-white bg-opacity-80 rounded-full px-1.5 py-0.5 text-xs text-gray-600 border border-gray-200 hover:bg-gray-100"
    reorderHandle.setAttribute("aria-label", "Reorder image")

    wrapper.appendChild(img)
    wrapper.appendChild(removeBtn)
    wrapper.appendChild(reorderHandle)

    return wrapper
  }

  initSortable() {
    this.sortable = Sortable.create(this.previewsTarget, {
      animation: 150,
      handler: '.image-preview-handle',
      onEnd: (evt) => {
        // Update model based on new DOM order
        const newOrder = []
        Array.from(this.previewsTarget.children).forEach((wrapper, index) => {
          const key = wrapper.dataset.key
          const item = this.items.find(i => i.key === key)
          console.log('Reordered item:', item, 'to index', index + 1)
          if (item) newOrder.push({...item, position: index + 1 })
        })

        this.items = newOrder
        this.syncInputFiles()
        // No need to renderPreviews() because Sortable already moved the DOM elements
      }
    })
  }

  remove(event) {
    const wrapper = event.target.closest('[data-key]')
    if (!wrapper) return
    const key = wrapper.dataset.key

    const index = this.items.findIndex(i => i.key === key)
    if (index === -1) return

    const item = this.items[index]
    if (item.type === 'existing') {
      this.markExistingForRemoval(item.id)
    }

    this.items.splice(index, 1)
    this.syncInputFiles()
    this.renderPreviews() // Will only remove the single element
  }

  markExistingForRemoval(id) {
    const paramName = this.removeParamNameValue
    const existingInput = this.element.querySelector(`input[name="${paramName}"][value="${id}"]`)
    if (existingInput) return

    // Check if we're dealing with ProductImage IDs (structured params)
    if (this.fieldBaseNameValue) {
      // For ProductImage model, mark via product_images_attributes with _destroy
      const destroyInput = document.createElement("input")
      destroyInput.type = "hidden"
      destroyInput.name = `${this.fieldBaseNameValue}[product_images_attributes][${id}][_destroy]`
      destroyInput.value = "1"
      this.element.appendChild(destroyInput)

      const idInput = document.createElement("input")
      idInput.type = "hidden"
      idInput.name = `${this.fieldBaseNameValue}[product_images_attributes][${id}][id]`
      idInput.value = id
      this.element.appendChild(idInput)
    } else {
      // Legacy: Add a hidden input to signal blob removal on submit
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = paramName
      input.value = id
      this.element.appendChild(input)
    }
  }

  // Reset selection and preview state to initial existingImages
  resetSelection() {
    try {
      // Clear input file element
      if (this.hasInputTarget && this.inputTarget) {
        try { this.inputTarget.value = '' } catch (e) { /* ignore */ }
      }

      // Remove images_to_remove hidden inputs
      try {
        const paramName = this.removeParamNameValue
        const removeInputs = Array.from(this.element.querySelectorAll(`input[name="${paramName}"]`))
        removeInputs.forEach(i => i.remove())
      } catch (e) { /* ignore */ }

      // Reset items to original
      this.items = (this.existingImagesValue || []).map(img => ({
        type: 'existing',
        key: this.generateKey(),
        ...img
      }))

      this.renderPreviews()
    } catch (e) {
      console.warn('image-preview: resetSelection failed', e)
    }
  }


  handleFormSubmit(event) {
    if (!this.fieldBaseNameValue && this.variantMode) return
    if (this.fieldBaseNameValue && !this.variantMode) return
    // Inject hidden inputs for product_images_attributes with position
    this.items.forEach((item, index) => {
      const position = index + 1
      const baseName = this.fieldBaseNameValue || 'product[product_variants_attributes][0]'

      if (item.type === 'existing') {
        // For existing images, send id and position
        const idInput = document.createElement('input')
        idInput.type = 'hidden'
        idInput.name = `${baseName}[product_images_attributes][${index}][id]`
        idInput.value = item.id
        this.element.appendChild(idInput)

        const posInput = document.createElement('input')
        posInput.type = 'hidden'
        posInput.name = `${baseName}[product_images_attributes][${index}][position]`
        posInput.value = position
        this.element.appendChild(posInput)
      } else if (item.type === 'new') {
        // For new images, send position only (image file already in input)
        // The position will be matched by index with the uploaded files
        const posInput = document.createElement('input')
        posInput.type = 'hidden'
        posInput.name = `${baseName}[product_images_positions][]`
        posInput.value = position
        this.element.appendChild(posInput)
      }
    })
  }
  clearPreviews() {
    if (this.hasPreviewsTarget) {
      this.previewsTarget.innerHTML = ""
    }
  }
}

// Delegated fallback: handle clicks for elements that have data-action="...image-preview#open"
// but which are not inside a data-controller="image-preview" wrapper (common in some show pages).
document.addEventListener("click", function (event) {
  try {
    const el = event.target.closest('[data-action*="image-preview#open"]')
    if (!el) return
    // If the element is already inside an image-preview controller instance, let Stimulus handle it.
    if (el.closest('[data-controller*="image-preview"]')) return

    // Prevent default and show fallback modal/image
    event.preventDefault()
    const imageUrl = extractImageUrlFromElement(el)
    if (!imageUrl) return

    // Try to find existing modal/image targets first
    let modal = document.querySelector('[data-image-preview-target="modal"]')
    let img = document.querySelector('[data-image-preview-target="image"]')

    // If none exist, create a minimal fallback modal (idempotent per page load)
    if (!modal || !img) {
      // Create modal wrapper
      modal = document.createElement("div")
      modal.setAttribute("data-image-preview-target", "modal")
      // Mark as fallback so escape handlers can find it
      modal.className = "fixed inset-0 z-50 flex items-center justify-center bg-black/60 __image-preview-fallback"
      modal.setAttribute("role", "dialog")
      modal.setAttribute("aria-hidden", "false")
      modal.tabIndex = -1

      const inner = document.createElement("div")
      inner.className = "bg-white rounded shadow-lg max-w-3xl w-full mx-4 p-4"

      const closeWrap = document.createElement("div")
      closeWrap.className = "flex justify-end"

      const closeBtn = document.createElement("button")
      closeBtn.type = "button"
      closeBtn.setAttribute("aria-label", "Close preview")
      closeBtn.className = "text-gray-600 hover:text-gray-900 text-2xl leading-none"
      closeBtn.innerHTML = "&times;"
      closeBtn.addEventListener("click", () => {
        try {
          if (img && img.dataset && img.dataset.__imagePreviewObjectUrl) {
            try { URL.revokeObjectURL(img.dataset.__imagePreviewObjectUrl) } catch (e) { }
            delete img.dataset.__imagePreviewObjectUrl
          }
        } catch (e) { }
        modal.classList.add("hidden")
        modal.setAttribute("aria-hidden", "true")
      })

      closeWrap.appendChild(closeBtn)
      inner.appendChild(closeWrap)

      const imgWrap = document.createElement("div")
      imgWrap.className = "flex items-center justify-center"

      img = document.createElement("img")
      img.setAttribute("data-image-preview-target", "image")
      img.src = ""
      img.alt = ""
      img.className = "max-h-[80vh] w-auto mx-auto object-contain"

      imgWrap.appendChild(img)
      inner.appendChild(imgWrap)
      modal.appendChild(inner)

      // Close when clicking on backdrop
      modal.addEventListener("click", (ev) => {
        if (ev.target === modal) {
          try {
            if (img && img.dataset && img.dataset.__imagePreviewObjectUrl) {
              try { URL.revokeObjectURL(img.dataset.__imagePreviewObjectUrl) } catch (e) { }
              delete img.dataset.__imagePreviewObjectUrl
            }
          } catch (e) { }
          modal.classList.add("hidden")
          modal.setAttribute("aria-hidden", "true")
        }
      })

      document.body.appendChild(modal)
    }

    const isSvg = /\.svg(\?|$)/i.test(imageUrl)
    if (isSvg) {
      const cacheBusted = imageUrl + (imageUrl.includes('?') ? '&' : '?') + 't=' + Date.now()
      fetch(cacheBusted, { cache: 'no-store' })
        .then(res => res.blob())
        .then(raw => {
          let svgBlob = raw
          try {
            if (!svgBlob.type || svgBlob.type === 'application/octet-stream') {
              svgBlob = svgBlob.slice(0, svgBlob.size, 'image/svg+xml')
            }
          } catch (e) { }
          const objUrl = URL.createObjectURL(svgBlob)
          try { img.dataset.__imagePreviewObjectUrl = objUrl } catch (e) { }
          img.src = objUrl
          img.alt = el.dataset.imageAlt || "Full size image"
          modal.classList.remove("hidden")
          modal.setAttribute("aria-hidden", "false")
          modal.tabIndex = -1
          modal.focus()
        })
        .catch(() => {
          img.src = imageUrl
          img.alt = el.dataset.imageAlt || "Full size image"
          modal.classList.remove("hidden")
          modal.setAttribute("aria-hidden", "false")
          modal.tabIndex = -1
          modal.focus()
        })
    } else {
      img.src = imageUrl
      img.alt = el.dataset.imageAlt || "Full size image"
      modal.classList.remove("hidden")
      modal.setAttribute("aria-hidden", "false")
      modal.tabIndex = -1
      modal.focus()
    }
  } catch (err) {
    // swallow fallback errors to avoid breaking other UI
    console.error("image-preview fallback error:", err)
  }
})
