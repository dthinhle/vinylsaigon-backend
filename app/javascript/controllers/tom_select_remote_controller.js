import { Controller } from "@hotwired/stimulus"
import TomSelect from "tom-select"

export default class extends Controller {
  static values = {
    url: String,
    valueField: { type: String, default: 'id' },
    labelField: { type: String, default: 'name' },
    searchField: { type: String, default: 'name' },
    preload: { type: String, default: 'focus' },
    allowCreate: { type: Boolean, default: false }
  }

  connect() {
    if (!this.element) return

    if (this.element._tomSelectInstance) {
      this.select = this.element._tomSelectInstance
      return
    }

    const config = {
      persist: false,
      valueField: this.valueFieldValue,
      labelField: this.labelFieldValue,
      searchField: this.searchFieldValue,
      preload: this.preloadValue,
      plugins: ['remove_button'],
      load: (query, callback) => {
        const url = query
          ? `${this.urlValue}?q=${encodeURIComponent(query)}`
          : this.urlValue

        fetch(url)
          .then(response => response.json())
          .then(data => callback(data))
          .catch((err) => {
            console.error('Error fetching data:', err)
            callback()
          })
      }
    }

    if (this.allowCreateValue) {
      config.create = true
    }

    this.select = new TomSelect(this.element, config)
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
