import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["form", "input"];
  static values = { parentId: Number };

  connect() {
    // no-op; elements are present when controller connects
  }

  toggle(event) {
    event.preventDefault();
    const button = event.currentTarget;
    const expanded = button.getAttribute("aria-expanded") === "true";
    if (expanded) {
      this.hide(button);
    } else {
      this.show(button);
    }
  }

  show(button) {
    if (this.hasFormTarget) {
      this.formTarget.classList.remove("hidden");
      this.formTarget.setAttribute("aria-hidden", "false");
    }
    button.setAttribute("aria-expanded", "true");

    // focus the first input if available after a tick (allow Turbo to render)
    setTimeout(() => {
      try {
        if (this.hasInputTarget) {
          this.inputTarget.focus();
        } else {
          const firstInput = this.element.querySelector("input, textarea, select");
          if (firstInput) firstInput.focus();
        }
      } catch (e) {
        // ignore focus errors
      }
    }, 0);
  }

  hide(button) {
    if (this.hasFormTarget) {
      this.formTarget.classList.add("hidden");
      this.formTarget.setAttribute("aria-hidden", "true");
    }
    button.setAttribute("aria-expanded", "false");
  }
}