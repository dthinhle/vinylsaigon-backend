import BaseAttributesController from "./base_attributes_controller"

export default class extends BaseAttributesController {
  static values = {
    fieldName: String,
    initial: String,
    initialValue: String,
    originalPrice: Number
  };

  get controllerName() {
    return "variant-attributes"
  }

  connect() {
    this.attributes = {}
    this.dirty = false
    this.errorRows = []
    this.allErrors = []

    try {
      if (this.initialValueValue && typeof this.initialValueValue === "string") {
        this.attributes = this.normalizeFormat(JSON.parse(this.initialValueValue))
      } else if (typeof this.initialValueValue === "object") {
        this.attributes = this.normalizeFormat(this.initialValueValue)
      } else {
        this.attributes = { attributes: [] }
      }
    } catch (err) {
      this.attributes = { attributes: [] }
      console.error("[variant_attributes] Error parsing initialValue:", err, this.initialValueValue)
    }
    this.renderRows()

    this.refreshTargets()
    this.addBlurListeners()
    this.autoResizeAllTextareas()
  }

  refreshTargets() {
  }

  updateHiddenField() {
    const attributesArray = []
    this.keyInputTargets.forEach((keyInput, idx) => {
      const name = keyInput.value.trim()
      const valueInput = this.valueInputTargets[idx]
      let value = valueInput ? valueInput.value : ""
      if (name) {
        if (name === "price") {
          if (!value || isNaN(value)) {
            value = this.hasOriginalPriceValue && !isNaN(this.originalPriceValue)
              ? this.originalPriceValue
              : ""
          }
        }
        attributesArray.push({ name, value })
      }
    })
    if (this.hasHiddenTarget) {
      this.hiddenTarget.value = JSON.stringify({ attributes: attributesArray })
    } else {
      console.warn("[variant_attributes] Hidden target not found.")
    }
  }

  addRow(event) {
    if (event) event.preventDefault()
    this.appendRow("", "")
    this.dirty = true
    this.refreshTargets()
    this.addBlurListeners()
    setTimeout(() => this.autoResizeAllTextareas(), 0)
  }

  removeRow(event) {
    event.preventDefault()
    const row = event.target.closest("tr")

    this.removeErrorRow(row)

    if (row) row.remove()
    this.dirty = true

    this.refreshTargets()
    this.addBlurListeners()

    setTimeout(() => {
      const noKeyInputs = !this.keyInputTargets || this.keyInputTargets.length === 0
      const noValueInputs = !this.valueInputTargets || this.valueInputTargets.length === 0
      if (noKeyInputs && noValueInputs) {
        this.errorRows = []
        this.allErrors = []
        const errorRows = this.rowsTarget.querySelectorAll(".variant-attr-error-row")
        errorRows.forEach(row => row.remove())
      } else {
        this.validateAllFields()
      }
    }, 0)
  }

  appendRow(key, value) {
    const row = document.createElement("tr")
    row.innerHTML = `
      <td class="border border-gray-300 rounded-l-lg transition-colors focus-within:bg-blue-50/30">
        <input type="text" class="w-full px-4 py-2.5 h-11 rounded-md border-0 bg-transparent focus:outline-none focus:ring-0" value="${this.escape(key)}" placeholder="Enter key" data-action="input->variant-attributes#onInput focus->variant-attributes#onFocus blur->variant-attributes#onBlur paste->variant-attributes#onPaste" data-variant-attributes-target="keyInput" />
      </td>
      <td class="border-l-0 border-t border-r border-b border-gray-300 rounded-r-lg transition-colors focus-within:bg-blue-50/30 focus-within:border-l">
        <textarea rows="1" class="mt-0 w-full px-4 py-2.5 rounded-md border-0 bg-transparent focus:outline-none focus:ring-0 resize-none overflow-hidden" placeholder="Enter value" data-action="input->variant-attributes#onInput focus->variant-attributes#onFocus blur->variant-attributes#onBlur paste->variant-attributes#onPaste" data-variant-attributes-target="valueInput">${this.escape(value)}</textarea>
      </td>
      <td class="p-2">
        <div class="flex items-center gap-1">
          <button
            type="button"
            data-action="variant-attributes#moveUp"
            class="bg-gray-200 hover:bg-gray-300 text-gray-700 font-medium rounded-lg transition-colors flex items-center justify-center size-8"
            aria-label="Move up"
          >
            <span class="material-icons text-base">keyboard_arrow_up</span>
          </button>
          <button
            type="button"
            data-action="variant-attributes#moveDown"
            class="bg-gray-200 hover:bg-gray-300 text-gray-700 font-medium rounded-lg transition-colors flex items-center justify-center size-8"
            aria-label="Move down"
          >
            <span class="material-icons text-base">keyboard_arrow_down</span>
          </button>
          <button
            type="button"
            data-action="variant-attributes#removeRow"
            class="bg-red-500 hover:bg-red-600 text-white font-medium rounded-lg transition-colors flex items-center justify-center size-8"
            aria-label="Remove attribute"
          >
            <span class="!flex material-icons size-6 text-base! text-white justify-center">delete</span>
          </button>
        </div>
      </td>
    `
    this.rowsTarget.appendChild(row)
    this.refreshTargets()
    this.addBlurListeners()
    setTimeout(() => this.autoResizeAllTextareas(), 0)
  }
}
