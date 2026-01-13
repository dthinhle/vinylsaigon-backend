import { Controller } from "@hotwired/stimulus"

// Payment transactions index controller - advanced filters dialog behavior
export default class extends Controller {
  static targets = ["moreFilters", "moreFiltersToggle"]

  connect() {
    try {
      if (this.hasMoreFiltersTarget) {
        this.moreFiltersTarget.classList.add("hidden")
        this.moreFiltersTarget.removeAttribute("aria-modal")
        this.moreFiltersTarget.removeAttribute("tabindex")
      }
      if (this.hasMoreFiltersToggleTarget) {
        this.moreFiltersToggleTarget.setAttribute("aria-expanded", "false")
      }
      if (this._outsideClickHandler) {
        document.removeEventListener("mousedown", this._outsideClickHandler)
        this._outsideClickHandler = null
      }
      if (this._escapeHandler) {
        document.removeEventListener("keydown", this._escapeHandler)
        this._escapeHandler = null
      }
    } catch (_) {}
  }

  toggleMoreFilters(event) {
    if (!this.hasMoreFiltersTarget) return
    const el = this.moreFiltersTarget
    const btn = this.hasMoreFiltersToggleTarget ? this.moreFiltersToggleTarget : null
    const wasHidden = el.classList.contains("hidden")

    if (wasHidden) {
      el.classList.remove("hidden")
      el.setAttribute("aria-modal", "true")
      el.setAttribute("tabindex", "-1")
      if (btn) btn.setAttribute("aria-expanded", "true")
      setTimeout(() => { el.focus(); this._trapFocus(el) }, 10)

      if (this._outsideClickHandler) document.removeEventListener("mousedown", this._outsideClickHandler)
      if (this._escapeHandler) document.removeEventListener("keydown", this._escapeHandler)

      this._suppressOutsideClicks = true
      setTimeout(() => { this._suppressOutsideClicks = false }, 300)

      this._outsideClickHandler = (e) => {
        if (this._suppressOutsideClicks) return
        try {
          if (!el.contains(e.target) && (!btn || !btn.contains(e.target))) {
            this.closeMoreFilters()
          }
        } catch (_) { this.closeMoreFilters() }
      }
      document.addEventListener("mousedown", this._outsideClickHandler)

      this._escapeHandler = (e) => { if (e.key === "Escape") this.closeMoreFilters() }
      document.addEventListener("keydown", this._escapeHandler)
    } else {
      this.closeMoreFilters()
    }
  }

  toggleMoreFiltersKeydown(event) {
    if (["Enter", " ", "Spacebar", "ArrowDown"].includes(event.key)) {
      event.preventDefault(); this.toggleMoreFilters(event)
    }
  }

  closeMoreFilters() {
    if (!this.hasMoreFiltersTarget) return
    const el = this.moreFiltersTarget
    const btn = this.hasMoreFiltersToggleTarget ? this.moreFiltersToggleTarget : null
    el.classList.add("hidden")
    el.removeAttribute("aria-modal")
    el.removeAttribute("tabindex")
    if (btn) btn.setAttribute("aria-expanded", "false")
    if (btn) btn.focus()
    if (this._outsideClickHandler) document.removeEventListener("mousedown", this._outsideClickHandler)
    if (this._escapeHandler) document.removeEventListener("keydown", this._escapeHandler)
    this._releaseFocusTrap()
  }

  _trapFocus(el) {
    this._focusTrapHandler = (e) => {
      const focusable = el.querySelectorAll('a, button, textarea, input, select, [tabindex]:not([tabindex="-1"])')
      const first = focusable[0]
      const last = focusable[focusable.length - 1]
      if (e.key === "Tab") {
        if (e.shiftKey) {
          if (document.activeElement === first) { e.preventDefault(); last.focus() }
        } else {
          if (document.activeElement === last) { e.preventDefault(); first.focus() }
        }
      }
    }
    el.addEventListener("keydown", this._focusTrapHandler)
  }

  _releaseFocusTrap() {
    if (!this.hasMoreFiltersTarget) return
    if (this._focusTrapHandler) this.moreFiltersTarget.removeEventListener("keydown", this._focusTrapHandler)
  }
}
