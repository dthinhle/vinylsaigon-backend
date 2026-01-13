import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { message: String };

  connect() {
    this._boundConfirm = this.confirm.bind(this);
    this.element.addEventListener("submit", this._boundConfirm, true);
  }

  disconnect() {
    if (this._boundConfirm) {
      this.element.removeEventListener("submit", this._boundConfirm, true);
      this._boundConfirm = null;
    }
  }

  confirm(event) {
    const msg = this.messageValue || "Are you sure?";
    if (!window.confirm(msg)) {
      event.preventDefault();
      event.stopImmediatePropagation();
    }
  }
}