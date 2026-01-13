import { Controller } from "@hotwired/stimulus"

// Orders index controller - handles advanced filters dialog and search
// Reuses the same patterns as products-index controller
export default class extends Controller {
  static targets = ["moreFilters", "moreFiltersToggle"];

  connect() {
    // Ensure dialog starts hidden and ARIA attributes are consistent on connect.
    try {
      if (this.hasMoreFiltersTarget) {
        this.moreFiltersTarget.classList.add("hidden");
        this.moreFiltersTarget.removeAttribute("aria-modal");
        this.moreFiltersTarget.removeAttribute("tabindex");
      }
      if (this.hasMoreFiltersToggleTarget) {
        this.moreFiltersToggleTarget.setAttribute("aria-expanded", "false");
      }

      // Remove any previously-registered global handlers (defensive cleanup)
      try {
        if (this._outsideClickHandler) {
          document.removeEventListener("mousedown", this._outsideClickHandler);
          this._outsideClickHandler = null;
        }
        if (this._escapeHandler) {
          document.removeEventListener("keydown", this._escapeHandler);
          this._escapeHandler = null;
        }
      } catch (cleanupErr) {
        // Ignore cleanup errors
      }
    } catch (err) {
      // Defensive: ignore any errors during connect
    }
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
        el.focus();
        this._trapFocus(el);
      }, 10);

      // Remove any existing outside-click/escape handlers to avoid duplicates
      try {
        if (this._outsideClickHandler) {
          document.removeEventListener("mousedown", this._outsideClickHandler);
        }
        if (this._escapeHandler) {
          document.removeEventListener("keydown", this._escapeHandler);
        }
      } catch (removeErr) {
        // Ignore removal errors
      }

      // Suppress immediate outside-clicks caused by the same user action that opened the dialog.
      this._suppressOutsideClicks = true;
      setTimeout(() => { this._suppressOutsideClicks = false; }, 300);

      this._outsideClickHandler = (e) => {
        if (this._suppressOutsideClicks) {
          return;
        }
        try {
          const clickedOutsideDialog = !el.contains(e.target);
          const clickedOutsideToggle = btn ? !btn.contains(e.target) : true;
          if (clickedOutsideDialog && clickedOutsideToggle) {
            this.closeMoreFilters();
          }
        } catch (err) {
          // Defensive: if something goes wrong during outside click handling, close the dialog
          this.closeMoreFilters();
        }
      }
      document.addEventListener("mousedown", this._outsideClickHandler)

      this._escapeHandler = (e) => {
        if (e.key === "Escape") {
          this.closeMoreFilters()
        }
      }
      document.addEventListener("keydown", this._escapeHandler)
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

    if (this._outsideClickHandler) {
      document.removeEventListener("mousedown", this._outsideClickHandler)
    }
    if (this._escapeHandler) {
      document.removeEventListener("keydown", this._escapeHandler)
    }
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
    if (this._focusTrapHandler) {
      this.moreFiltersTarget.removeEventListener("keydown", this._focusTrapHandler)
    }
  }

  // Search handler (placeholder for future implementation)
  search(event) {
    // Can be implemented for live search if needed
    // For now, form submission handles the search
  }
}