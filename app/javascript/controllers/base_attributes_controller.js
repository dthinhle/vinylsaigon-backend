import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["rows", "hidden", "keyInput", "valueInput", "error", "initialValue"];

  get controllerName() {
    throw new Error("Subclass must implement controllerName getter")
  }

  get errorRowClass() {
    return `${this.controllerName}-error-row`
  }

  get errorClass() {
    return `${this.controllerName}-error`
  }

  get keyInputSelector() {
    return `input[data-${this.controllerName}-target="keyInput"]`
  }

  get valueInputSelector() {
    return `textarea[data-${this.controllerName}-target="valueInput"]`
  }

  connect() {
    this.attributes = {}
    this.dirty = false
    this.errorRows = []
    this.allErrors = []

    this.attributes = this.normalizeFormat(this.initialValue)

    this.renderRows()

    this.updateHiddenField()
    this.addBlurListeners()
    this.autoResizeAllTextareas()
  }

  addBlurListeners() {
    this.keyInputTargets?.forEach((input, idx) => {
      input.addEventListener("blur", (e) => this.validateFieldOnBlur(e, idx, "key"))
    })
    this.valueInputTargets?.forEach((input, idx) => {
      input.addEventListener("blur", (e) => this.validateFieldOnBlur(e, idx, "value"))
      input.addEventListener("keyup", (e) => this.autoResizeTextarea(e.target))
      input.addEventListener("paste", (e) => {
        setTimeout(() => this.autoResizeTextarea(e.target), 0)
      })
    })
  }

  autoResizeTextarea(textarea) {
    const td = textarea.closest("td")
    if (!td) return

    textarea.style.height = "auto"
    const scrollHeight = textarea.scrollHeight
    textarea.style.height = scrollHeight + "px"
    td.style.height = scrollHeight + "px"
  }

  autoResizeAllTextareas() {
    this.valueInputTargets?.forEach((textarea) => {
      this.autoResizeTextarea(textarea)
    })
  }

  validateFieldOnBlur(event, idx, type) {
    const input = event.target
    const row = input.closest("tr")
    const { keyInput, valueInput } = this.getRowInputs(row)

    const key = keyInput ? keyInput.value.trim() : ""
    const value = valueInput ? valueInput.value.trim() : ""

    if (type === "key") {
      if (key) {
        return
      }
      this.validateAllFields()
    } else if (type === "value") {
      if (value && !key) {
        this.validateAllFields()
        return
      }
      if ((key && value) || !value) {
        this.validateAllFields()
      }
    }
  }

  validateAllFields() {
    const errorRows = this.rowsTarget.querySelectorAll(`.${this.errorRowClass}`)
    errorRows.forEach(row => row.remove())

    this.errorRows = []
    this.allErrors = []

    this.keyInputTargets?.forEach((input) => {
      const cell = input.closest("td")
      cell.classList.remove("border-red-300", "bg-red-50/50", "focus-within:border-red-400", "focus-within:bg-red-50/30")
      cell.classList.add("border-gray-300", "focus-within:bg-blue-50/30")
    })
    this.valueInputTargets?.forEach((input) => {
      const cell = input.closest("td")
      cell.classList.remove("border-red-300", "bg-red-50/50", "focus-within:border-red-400", "focus-within:bg-red-50/30", "focus-within:border-l-red-400")
      cell.classList.add("border-gray-300", "focus-within:bg-blue-50/30", "focus-within:border-l", "focus-within:border-l-blue-500")
    })

    const keys = this.keyInputTargets.map(input => input.value.trim().toLowerCase())

    this.keyInputTargets.forEach((keyInput, idx) => {
      const valueInput = this.valueInputTargets[idx]
      const key = keyInput.value.trim()
      const value = valueInput ? valueInput.value.trim() : ""

      let errorMsg = ""

      if (!key || !value) {
        errorMsg = "Key and Value cannot be empty."
      } else if (keys.filter(k => k === key.toLowerCase()).length > 1) {
        errorMsg = "Duplicate key."
      }

      if (errorMsg) {
        this.showFieldError(keyInput, errorMsg, idx, "key")
        this.errorRows.push(idx)
        this.allErrors.push({ message: errorMsg, row: idx })
      }
    })
  }

  removeErrorRow(row) {
    const nextRow = row.nextElementSibling
    if (nextRow && nextRow.classList.contains(this.errorRowClass)) {
      nextRow.remove()
    }
  }

  getRowInputs(row) {
    const keyInput = row.querySelector(this.keyInputSelector)
    const valueInput = row.querySelector(this.valueInputSelector)
    return { keyInput, valueInput }
  }

  showFieldError(input, errorMsg, idx, type) {
    const cell = input.closest("td")
    const row = input.closest("tr")

    const allCells = row.querySelectorAll("td")
    allCells.forEach(c => {
      c.classList.remove("border-red-300", "bg-red-50/50", "focus-within:border-red-400", "focus-within:bg-red-50/30", "focus-within:border-l-red-400")
    })

    this.removeErrorRow(row)

    if (errorMsg) {
      const keyCell = row.querySelector("td:first-child")
      const valueCell = row.querySelector("td:nth-child(2)")

      if (keyCell) {
        keyCell.classList.remove("border-gray-300", "focus-within:bg-blue-50/30")
        keyCell.classList.add("border-red-300", "bg-red-50/50", "focus-within:border-red-400", "focus-within:bg-red-50/30")
      }

      if (valueCell) {
        valueCell.classList.remove("border-gray-300", "focus-within:bg-blue-50/30", "focus-within:border-l-blue-500")
        valueCell.classList.add("border-red-300", "bg-red-50/50", "focus-within:border-red-400", "focus-within:bg-red-50/30", "focus-within:border-l", "focus-within:border-l-red-400")
      }

      const errorRow = document.createElement("tr")
      errorRow.className = this.errorRowClass
      const td = document.createElement("td")
      td.colSpan = 3
      td.className = `${this.errorClass} product-form-error px-0 pb-3`
      td.innerHTML = `
        <div class="flex items-start gap-2 border-l-4 border-red-300 bg-red-50 text-red-700 px-3 py-2 text-sm rounded-r-md">
          <svg class="w-4 h-4 text-red-400 mt-0.5 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"></path>
          </svg>
          <span>${errorMsg}</span>
        </div>
      `
      errorRow.appendChild(td)
      row.parentNode.insertBefore(errorRow, row.nextSibling)
    }
  }

  renderRows() {
    this.rowsTarget.innerHTML = ""
    const attributesArray = this.attributes.attributes || []
    if (attributesArray.length === 0) {
      this.appendRow("", "")
    } else {
      attributesArray.forEach((attr) => {
        this.appendRow(attr.name || "", attr.value || "")
      })
    }
    this.addBlurListeners()
    setTimeout(() => this.autoResizeAllTextareas(), 0)
  }

  addRow(event) {
    if (event) event.preventDefault()
    this.appendRow("", "")
    this.dirty = true
    this.addBlurListeners()
    setTimeout(() => this.autoResizeAllTextareas(), 0)
  }

  moveUp(event) {
    event.preventDefault()
    const row = event.target.closest("tr")
    const previousRow = row.previousElementSibling

    if (previousRow) {
      row.parentNode.insertBefore(row, previousRow)
      this.dirty = true
      this.syncAttributesFromDOM()
      this.updateHiddenField()
      setTimeout(() => this.validateAllFields(), 0)
    }
  }

  moveDown(event) {
    event.preventDefault()
    const row = event.target.closest("tr")
    const nextRow = row.nextElementSibling

    let targetRow = nextRow
    while (targetRow && targetRow.classList.contains(this.errorRowClass)) {
      targetRow = targetRow.nextElementSibling
    }

    if (targetRow) {
      row.parentNode.insertBefore(targetRow, row)
      this.dirty = true
      this.syncAttributesFromDOM()
      this.updateHiddenField()
      setTimeout(() => this.validateAllFields(), 0)
    }
  }

  syncAttributesFromDOM() {
    const attributesArray = []
    this.keyInputTargets.forEach((keyInput, idx) => {
      const name = keyInput.value.trim()
      const valueInput = this.valueInputTargets[idx]
      const value = valueInput ? valueInput.value : ""
      if (name) {
        attributesArray.push({ name, value })
      }
    })
    this.attributes = { attributes: attributesArray }
  }

  appendRow(key, value) {
    const row = document.createElement("tr")
    row.innerHTML = `
      <td class="border border-gray-300 rounded-l-lg transition-colors focus-within:border-blue-500 focus-within:bg-blue-50/30">
        <input type="text" class="w-full px-4 py-2.5 h-11 rounded-md border-0 bg-transparent focus:outline-none focus:ring-0" value="${this.escape(key)}" placeholder="Enter key" data-action="input->${this.controllerName}#onInput focus->${this.controllerName}#onFocus blur->${this.controllerName}#onBlur paste->${this.controllerName}#onPaste" data-${this.controllerName}-target="keyInput" />
      </td>
      <td class="border-l-0 border-t border-r border-b border-gray-300 rounded-r-lg transition-colors focus-within:border-blue-500 focus-within:bg-blue-50/30 focus-within:border-l focus-within:border-l-blue-500">
        <textarea rows="1" class="mt-0 w-full px-4 py-2.5 rounded-md border-0 bg-transparent focus:outline-none focus:ring-0 resize-none overflow-hidden" placeholder="Enter value" data-action="input->${this.controllerName}#onInput focus->${this.controllerName}#onFocus blur->${this.controllerName}#onBlur paste->${this.controllerName}#onPaste" data-${this.controllerName}-target="valueInput">${this.escape(value)}</textarea>
      </td>
      <td class="p-2">
        <div class="flex items-center gap-1">
          <button
            type="button"
            data-action="${this.controllerName}#moveUp"
            class="bg-gray-200 hover:bg-gray-300 text-gray-700 font-medium rounded-lg transition-colors flex items-center justify-center size-8"
            aria-label="Move up"
          >
            <span class="material-icons text-base">keyboard_arrow_up</span>
          </button>
          <button
            type="button"
            data-action="${this.controllerName}#moveDown"
            class="bg-gray-200 hover:bg-gray-300 text-gray-700 font-medium rounded-lg transition-colors flex items-center justify-center size-8"
            aria-label="Move down"
          >
            <span class="material-icons text-base">keyboard_arrow_down</span>
          </button>
          <button
            type="button"
            data-action="${this.controllerName}#removeRow"
            class="bg-red-500 hover:bg-red-600 text-white font-medium rounded-lg transition-colors flex items-center justify-center size-8"
            aria-label="Remove attribute"
          >
            <span class="!flex material-icons size-6 text-base! text-white justify-center">delete</span>
          </button>
        </div>
      </td>
    `
    this.rowsTarget.appendChild(row)
    this.addBlurListeners()
    setTimeout(() => this.autoResizeAllTextareas(), 0)
  }

  removeRow(event) {
    event.preventDefault()
    const row = event.target.closest("tr")

    this.removeErrorRow(row)

    if (row) row.remove()
    this.dirty = true

    this.addBlurListeners()

    setTimeout(() => {
      const noKeyInputs = !this.keyInputTargets || this.keyInputTargets.length === 0
      const noValueInputs = !this.valueInputTargets || this.valueInputTargets.length === 0
      if (noKeyInputs && noValueInputs) {
        this.errorRows = []
        this.allErrors = []
        const errorRows = this.rowsTarget.querySelectorAll(`.${this.errorRowClass}`)
        errorRows.forEach(row => row.remove())
      } else {
        this.validateAllFields()
      }
    }, 0)
  }

  onInput(event) {
    this.dirty = true

    const input = event.target
    const row = input.closest("tr")
    const { keyInput, valueInput } = this.getRowInputs(row)

    const key = keyInput ? keyInput.value.trim() : ""
    const value = valueInput ? valueInput.value.trim() : ""

    if (key && value) {
      this.validateAllFields()
    }

    this.updateHiddenField()
  }

  onFocus(event) {
  }

  onPaste(event) {
    const pasteData = event.clipboardData.getData('text/plain')

    if (!pasteData) return

    const rows = pasteData.split('\n').filter(row => row.trim())
    if (rows.length === 0) return

    const input = event.target
    const currentRow = input.closest("tr")
    const { keyInput, valueInput } = this.getRowInputs(currentRow)

    const isPastingIntoKey = input === keyInput

    const allRows = Array.from(this.rowsTarget.querySelectorAll("tr")).filter(row => !row.classList.contains(this.errorRowClass))
    const currentRowIndex = allRows.indexOf(currentRow)

    if (currentRowIndex === -1) return

    event.preventDefault()

    rows.forEach((row, offset) => {
      const columns = row.split('\t')
      const targetRowIndex = currentRowIndex + offset

      let key = ''
      let value = ''

      if (columns.length === 1) {
        if (isPastingIntoKey) {
          key = columns[0].trim()
        } else {
          value = columns[0].trim()
        }
      } else {
        key = columns[0].trim()
        value = columns.slice(1).join('\t').trim()
      }

      let targetRow
      if (targetRowIndex < allRows.length) {
        targetRow = allRows[targetRowIndex]
        const inputs = this.getRowInputs(targetRow)

        if (isPastingIntoKey || columns.length > 1) {
          if (inputs.keyInput) inputs.keyInput.value = key
        }
        if (!isPastingIntoKey || columns.length > 1) {
          if (inputs.valueInput) {
            inputs.valueInput.value = value
            this.autoResizeTextarea(inputs.valueInput)
          }
        }
      } else {
        if (columns.length > 1) {
          this.appendRow(key, value)
        } else {
          if (isPastingIntoKey) {
            this.appendRow(key, '')
          } else {
            this.appendRow('', value)
          }
        }
      }
    })

    this.dirty = true
    this.updateHiddenField()
    setTimeout(() => this.validateAllFields(), 0)
  }

  onBlur(event) {
    const input = event.target
    const row = input.closest("tr")
    const { keyInput, valueInput } = this.getRowInputs(row)

    if (input === keyInput) {
      const keyInputs = Array.from(this.keyInputTargets)
      const idx = keyInputs.indexOf(input)
      if (idx !== -1) {
        this.validateFieldOnBlur(event, idx, "key")
      }
    } else if (input === valueInput) {
      const valueInputs = Array.from(this.valueInputTargets)
      const idx = valueInputs.indexOf(input)
      if (idx !== -1) {
        this.validateFieldOnBlur(event, idx, "value")
      }
    }
  }

  updateHiddenField() {
    const attributesArray = []
    this.keyInputTargets.forEach((keyInput, idx) => {
      const name = keyInput.value.trim()
      const valueInput = this.valueInputTargets[idx]
      let value = valueInput ? valueInput.value : ""
      if (name) {
        attributesArray.push({ name, value })
      }
    })
    if (this.hasHiddenTarget) {
      this.hiddenTarget.value = JSON.stringify({ attributes: attributesArray })
    }
  }

  escape(str) {
    return String(str)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;")
  }

  normalizeFormat(data) {
    if (!data || typeof data !== "object") {
      return { attributes: [] }
    }

    if (data.attributes && Array.isArray(data.attributes)) {
      return data
    }

    const attributesArray = Object.keys(data).map(key => ({
      name: key,
      value: data[key]
    }))

    return { attributes: attributesArray }
  }

  get initialValue() {
    let raw
    if (this.hasInitialValue) {
      raw = this.initialValueValue
    } else {
      raw = this.element.dataset[`${this.camelCaseName}InitialValue`]
      if (raw === undefined || raw === null || raw === "") {
        raw = this.element.getAttribute(`data-${this.controllerName}-initial-value`)
      }
    }
    if (typeof raw === "object" && raw !== null) {
      return raw
    }
    if (typeof raw === "string") {
      try {
        const parsed = JSON.parse(raw)
        return typeof parsed === "object" && parsed !== null ? parsed : {}
      } catch (err) {
        return {}
      }
    }
    return {}
  }

  get camelCaseName() {
    return this.controllerName.replace(/-([a-z])/g, (g) => g[1].toUpperCase())
  }
}
