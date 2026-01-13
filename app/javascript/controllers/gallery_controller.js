import { Controller } from "@hotwired/stimulus"
/* Focus trap and click outside handled by custom logic below */

export default class extends Controller {
  static targets = [
    "modal", "image", "prevButton", "nextButton", "closeButton", "galleryItem", "modalImage"
  ]
  static values = {
    index: Number,
    open: Boolean
  }

  connect() {
    this.openValue = false
    this.indexValue = 0
    this._boundKeydown = this._onKeydown.bind(this)
    this._boundClickOutside = this._onClickOutside.bind(this)
  }

  disconnect() {
    this._removeListeners()
    this._removeClickOutside()
  }

  open(event) {
    if (event) event.preventDefault()
    const idx = event?.currentTarget?.dataset.index
    this.indexValue = idx ? parseInt(idx, 10) : 0
    this.openValue = true
    this._showModal()
  }

  close(event) {
    if (event) event.preventDefault()
    this.openValue = false
    this._hideModal()
    this.imageTargets.forEach((img, i) => {
      img.hidden = false
      img.setAttribute("aria-hidden", "false")
      img.tabIndex = 0
    })
  }

  next() {
    if (this.indexValue < this.imageTargets.length - 1) {
      this.indexValue++
      this._updateImage()
    }
  }

  prev() {
    if (this.indexValue > 0) {
      this.indexValue--
      this._updateImage()
    }
  }

  _onClickOutside(event) {
    if (!this.openValue) return
    if (!this.modalTarget.contains(event.target)) {
      this.close()
    }
  }

  _onKeydown(e) {
    if (!this.openValue) return
    switch (e.key) {
      case "ArrowRight":
        this.next()
        e.preventDefault()
        break
      case "ArrowLeft":
        this.prev()
        e.preventDefault()
        break
      case "Escape":
        this.close()
        e.preventDefault()
        break
      case "Tab":
        this._handleTabKey(e)
        break
      case "Enter":
      case " ":
        if (document.activeElement === this.nextButtonTarget) {
          this.next()
          e.preventDefault()
        } else if (document.activeElement === this.prevButtonTarget) {
          this.prev()
          e.preventDefault()
        } else if (document.activeElement === this.closeButtonTarget) {
          this.close()
          e.preventDefault()
        }
        break
    }
  }

  _showModal() {
    this.modalTarget.removeAttribute("aria-hidden")
    this.modalTarget.setAttribute("aria-modal", "true")
    this.modalTarget.setAttribute("role", "dialog")
    this.modalTarget.setAttribute("aria-labelledby", "product-images-heading")
    this.modalTarget.style.display = "flex"
    this._updateImage()
    this._addListeners()
    this._addClickOutside()
    this._trapInitialFocus()
  }

  _hideModal() {
    this.modalTarget.setAttribute("aria-hidden", "true")
    this.modalTarget.removeAttribute("aria-modal")
    this.modalTarget.removeAttribute("role")
    this.modalTarget.removeAttribute("aria-labelledby")
    this.modalTarget.style.display = "none"
    this._removeListeners()
    this._removeClickOutside()
    this._restoreTriggerFocus()
  }

  _updateImage() {
    if (this.hasModalImageTarget && this.imageTargets[this.indexValue]) {
      this.modalImageTarget.src = this.imageTargets[this.indexValue].src
      this.modalImageTarget.alt = this.imageTargets[this.indexValue].alt
    }
    this.imageTargets.forEach((img, i) => {
      img.hidden = i !== this.indexValue
      img.setAttribute("aria-hidden", i !== this.indexValue)
      img.tabIndex = i === this.indexValue ? 0 : -1
    })
    this._updateNavButtons()
  }

  _updateNavButtons() {
    this.prevButtonTarget.disabled = this.indexValue === 0
    this.nextButtonTarget.disabled = this.indexValue === this.imageTargets.length - 1
  }

  _addListeners() {
    document.addEventListener("keydown", this._boundKeydown)
  }

  _addClickOutside() {
    document.addEventListener("mousedown", this._boundClickOutside, true)
    document.addEventListener("touchstart", this._boundClickOutside, true)
  }

  _removeClickOutside() {
    document.removeEventListener("mousedown", this._boundClickOutside, true)
    document.removeEventListener("touchstart", this._boundClickOutside, true)
  }

  _removeListeners() {
    document.removeEventListener("keydown", this._boundKeydown)
  }

  _trapInitialFocus() {
    if (this.imageTargets[this.indexValue]) {
      this.imageTargets[this.indexValue].focus()
    } else if (this.closeButtonTarget) {
      this.closeButtonTarget.focus()
    }
  }

  _restoreTriggerFocus() {
    if (this.hasGalleryItemTarget && this.galleryItemTargets[this.indexValue]) {
      this.galleryItemTargets[this.indexValue].focus()
    }
  }

  _focusableElements() {
    return Array.from(this.modalTarget.querySelectorAll(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    )).filter(el => !el.disabled && !el.hidden && el.offsetParent !== null)
  }

  _handleTabKey(e) {
    const focusable = this._focusableElements()
    if (focusable.length === 0) return
    const first = focusable[0]
    const last = focusable[focusable.length - 1]
    if (e.shiftKey) {
      if (document.activeElement === first) {
        last.focus()
        e.preventDefault()
      }
    } else {
      if (document.activeElement === last) {
        first.focus()
        e.preventDefault()
      }
    }
  }
}
