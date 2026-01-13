import BulkActionsController from "./bulk_actions_controller"

export default class extends BulkActionsController {
  static targets = [...BulkActionsController.targets, "moreFilters", "moreFiltersToggle"]

  connect() {
    super.connect()

    // Ensure dialog starts hidden and ARIA attributes are consistent on connect.
    try {
      if (this.hasMoreFiltersTarget) {
        this.moreFiltersTarget.classList.add("hidden")
        this.moreFiltersTarget.removeAttribute("aria-modal")
        this.moreFiltersTarget.removeAttribute("tabindex")
      }
      if (this.hasMoreFiltersToggleTarget) {
        this.moreFiltersToggleTarget.setAttribute("aria-expanded", "false")
      }

      // Remove any previously-registered global handlers (defensive cleanup)
      try {
        if (this._outsideClickHandler) {
          document.removeEventListener("mousedown", this._outsideClickHandler)
          this._outsideClickHandler = null
        }
        if (this._escapeHandler) {
          document.removeEventListener("keydown", this._escapeHandler)
          this._escapeHandler = null
        }
      } catch (cleanupErr) {
      }
    } catch (err) {
      // Defensive: ignore any errors during connect
    }
  }

  getResourceName() {
    return 'product'
  }

  getDefaultDeleteUrl() {
    return '/admin/products/destroy_selected'
  }

  getConfirmMessage() {
    return "Are you sure you want to delete the selected products? This action cannot be undone."
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
      setTimeout(() => {
        el.focus()
        this._trapFocus(el)
      }, 10)
      // Remove any existing outside-click/escape handlers to avoid duplicates
      try {
        if (this._outsideClickHandler) {
          document.removeEventListener("mousedown", this._outsideClickHandler)
        }
        if (this._escapeHandler) {
          document.removeEventListener("keydown", this._escapeHandler)
        }
      } catch (removeErr) {
      }

      // Suppress immediate outside-clicks caused by the same user action that opened the dialog.
      // Increase suppression window slightly to avoid race with mousedown/click ordering.
      this._suppressOutsideClicks = true
      setTimeout(() => { this._suppressOutsideClicks = false }, 300)

      this._outsideClickHandler = (e) => {
        if (this._suppressOutsideClicks) {
          return
        }
        // If there's no toggle button, only check the dialog element.
        try {
          const clickedOutsideDialog = !el.contains(e.target)
          const clickedOutsideToggle = btn ? !btn.contains(e.target) : true
          if (clickedOutsideDialog && clickedOutsideToggle) {
            this.closeMoreFilters()
          }
        } catch (err) {
          // Defensive: if something goes wrong during outside click handling, close the dialog
          this.closeMoreFilters()
        }
      }
      document.addEventListener("mousedown", this._outsideClickHandler)
      document.addEventListener("keydown", this._escapeHandler = (e) => {
        if (e.key === "Escape") {
          this.closeMoreFilters()
        }
      })
    } else {
      this.closeMoreFilters()
    }
  }

  toggleMoreFiltersKeydown(event) {
    if (event.key === "Enter" || event.key === " " || event.key === "Spacebar" || event.key === "ArrowDown") {
      event.preventDefault()
      this.toggleMoreFilters(event)
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
    document.removeEventListener("mousedown", this._outsideClickHandler)
    document.removeEventListener("keydown", this._escapeHandler)
    this._releaseFocusTrap()
  }

  _trapFocus(el) {
    this._focusTrapHandler = (e) => {
      const focusable = el.querySelectorAll('a, button, textarea, input, select, [tabindex]:not([tabindex="-1"])')
      const first = focusable[0]
      const last = focusable[focusable.length - 1]
      if (e.key === "Tab") {
        if (e.shiftKey) {
          if (document.activeElement === first) {
            e.preventDefault()
            last.focus()
          }
        } else {
          if (document.activeElement === last) {
            e.preventDefault()
            first.focus()
          }
        }
      }
    }
    el.addEventListener("keydown", this._focusTrapHandler)
  }

  _releaseFocusTrap() {
    if (!this.hasMoreFiltersTarget) return
    this.moreFiltersTarget.removeEventListener("keydown", this._focusTrapHandler)
  }

  // Compat shim for data-action input->products-index#search — prevents missing-action runtime error
  search(event) {
    try {
      const candidates = ["performSearch", "handleSearch", "_search", "doSearch", "filter", "searchProducts"]
      for (let i = 0; i < candidates.length; i++) {
        const name = candidates[i]
        const fn = this[name]
        if (typeof fn === "function") {
          try {
            // Try passing the full event first
            fn.call(this, event)
          } catch (e) {
            console.log('🚀🚀🚀 ====== e:', e)
            try {
              // Fallback: pass just the input value if available
              if (event && event.target) {
                fn.call(this, event.target.value)
              }
            } catch (e2) {
              console.log('🚀🚀🚀 ====== e2:', e2)
              // swallow
            }
          }
          return
        }
      }
    } catch (err) {
      console.log('🚀🚀🚀 ====== err:', err)
      // swallow
    }
    // no-op fallback to satisfy Stimulus action binding
  }
}
