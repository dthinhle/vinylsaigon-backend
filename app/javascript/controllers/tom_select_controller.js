import { Controller } from "@hotwired/stimulus"
import TomSelect from "tom-select"

export default class extends Controller {
  connect() {
    if (!this.element) return

    // If a TomSelect instance is already attached to this element, reuse it and skip init
    if (this.element._tomSelectInstance) {
      this.select = this.element._tomSelectInstance
      return
    }

    this.select = new TomSelect(this.element, {
      persist: false,
      create: false,
      plugins: ['remove_button'],
    })

    // store a safe DOM reference so other code can detect the instance
    this.element._tomSelectInstance = this.select
  }

  disconnect() {
    const instance = this.select || (this.element && this.element._tomSelectInstance)

    if (instance && typeof instance.destroy === "function") {
      instance.destroy()
      this.select = null
      if (this.element) delete this.element._tomSelectInstance
    }
  }
}
