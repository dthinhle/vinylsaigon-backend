import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["form", "toggleButton"];
  static values = { sectionId: Number };

  connect() {
    // Ensure ARIA reflects current visibility on connect
    if (this.hasFormTarget && this.hasToggleButtonTarget) {
      const hidden = this.formTarget.classList.contains("hidden");
      this.toggleButtonTarget.setAttribute("aria-expanded", (!hidden).toString());
      this.formTarget.setAttribute("aria-hidden", hidden.toString());
    }
  }

  toggle(event) {
    if (event) event.preventDefault();
    if (!this.hasFormTarget) return;

    // If this controller is attached at the section-level it will have a sectionIdValue set.
    // In that case we always open the modal-based create flow rather than toggling inline form.
    if (this.sectionIdValue) {
      document.dispatchEvent(new CustomEvent('menu:item:create', { detail: { sectionId: this.sectionIdValue } }));
      return;
    }

    this.formTarget.classList.toggle("hidden");
    const hidden = this.formTarget.classList.contains("hidden");

    if (this.hasToggleButtonTarget) {
      this.toggleButtonTarget.setAttribute("aria-expanded", (!hidden).toString());
    }

    this.formTarget.setAttribute("aria-hidden", hidden.toString());

    if (!hidden) {
      // focus first focusable element inside form when shown
      const first = this.formTarget.querySelector("input:not([type='hidden']), select, textarea, button");
      if (first) first.focus();
    } else {
      // if hiding, remove focus from any inputs inside the form
      const active = document.activeElement;
      if (this.formTarget.contains(active)) {
        active.blur();
      }
    }
  }
}