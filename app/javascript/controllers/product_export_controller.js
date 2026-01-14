import { Controller } from "@hotwired/stimulus"
import TomSelect from "tom-select"

export default class extends Controller {
  static targets = [
    "selector",
    "productsList",
    "productsContainer",
    "count",
    "exportBtn",
    "clearBtn",
    "emptyRow",
    "productRowTemplate",
    "messageContainer",
    "hoursSelect",
    "recentExportBtn"
  ]

  connect() {
    this.selectedProducts = new Map()
    this.initializeTomSelect()
  }

  disconnect() {
    if (this.tomSelect) {
      this.tomSelect.destroy()
    }
  }

  initializeTomSelect() {
    const initialProducts = JSON.parse(this.selectorTarget.dataset.initialProducts || '[]')

    this.tomSelect = new TomSelect(this.selectorTarget, {
      valueField: 'id',
      labelField: 'name',
      searchField: ['name', 'sku'],
      placeholder: 'Type to search products...',
      closeAfterSelect: false,
      preload: 'focus',
      load: (query, callback) => {
        if (!query.length) {
          callback(initialProducts)
          return
        }

        const limit = 50 + this.selectedProducts.size

        fetch(`/admin/selectors/products?q=${encodeURIComponent(query)}&limit=${limit}`)
          .then(response => response.json())
          .then(data => callback(data))
          .catch(() => callback())
      },
      render: {
        option: (item, escape) => {
          return `<div class="py-2">
            <div class="font-medium">${escape(item.name)}</div>
            <div class="text-xs text-gray-500">SKU: ${escape(item.sku)}</div>
            ${item.category ? `<div class="text-xs text-gray-400">${escape(item.category)}</div>` : ''}
          </div>`
        },
        item: (item, escape) => {
          return `<div>${escape(item.name)}</div>`
        }
      },
      onChange: (value) => {
        if (value) {
          this.addProduct()
          this.tomSelect.clear()
        }
      }
    })
  }

  addProduct() {
    const productId = this.tomSelect.getValue()
    if (!productId || this.selectedProducts.has(productId)) {
      return
    }

    const option = this.tomSelect.options[productId]
    if (!option) return

    this.selectedProducts.set(productId, {
      id: productId,
      sku: option.sku,
      name: option.name,
      category: option.category || 'N/A'
    })

    this.updateProductsList()
    this.updateButtons()
    this.removeProductOption(productId)
    this.tomSelect.clear()
  }

  removeProductOption(productId) {
    this.tomSelect.removeOption(productId)
  }

  removeProduct(event) {
    const row = event.target.closest('tr')
    const productId = row.dataset.productId

    this.selectedProducts.delete(productId)
    this.updateProductsList()
    this.updateButtons()
  }

  clearProducts() {
    if (!confirm('Are you sure you want to clear all selected products?')) {
      return
    }

    this.selectedProducts.clear()
    this.updateProductsList()
    this.updateButtons()
    this.showMessage('All products cleared', 'info')
  }

  updateProductsList() {
    const tbody = this.productsListTarget

    if (this.selectedProducts.size === 0) {
      tbody.innerHTML = ''
      const emptyRow = this.emptyRowTarget.cloneNode(true)
      emptyRow.removeAttribute('data-product-export-target')
      tbody.appendChild(emptyRow)
    } else {
      tbody.innerHTML = ''
      this.selectedProducts.forEach((product, id) => {
        const row = this.createProductRow(product)
        tbody.appendChild(row)
      })
    }

    this.countTarget.textContent = this.selectedProducts.size
  }

  createProductRow(product) {
    const template = this.productRowTemplateTarget
    const row = template.content.cloneNode(true).querySelector('tr')

    row.dataset.productId = product.id
    row.querySelector('[data-field="sku"]').textContent = product.sku
    row.querySelector('[data-field="name"]').textContent = product.name
    row.querySelector('[data-field="category"]').textContent = product.category

    return row
  }

  updateButtons() {
    const hasProducts = this.selectedProducts.size > 0
    this.exportBtnTarget.disabled = !hasProducts
    this.clearBtnTarget.disabled = !hasProducts
  }

  async exportProducts() {
    if (this.selectedProducts.size === 0) {
      this.showMessage('Please select at least one product to export', 'error')
      return
    }

    const productIds = Array.from(this.selectedProducts.keys())
    this.exportBtnTarget.disabled = true
    this.showMessage('Generating export... Please wait.', 'info')

    try {
      const response = await fetch('/admin/product_data_transfer/generate_export', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ product_ids: productIds })
      })

      if (response.status === 423) {
        this.showMessage('Another export is already in progress. Please wait.', 'error')
        this.exportBtnTarget.disabled = false
        return
      }

      if (!response.ok) {
        const error = await response.json()
        throw new Error(error.error || 'Export failed')
      }

      const blob = await response.blob()
      const contentDisposition = response.headers.get('Content-Disposition')
      const filenameMatch = contentDisposition?.match(/filename="?(.+?)"?$/i)
      const filename = filenameMatch ? filenameMatch[1] : 'product_export.json.gz'

      const url = window.URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = filename
      document.body.appendChild(a)
      a.click()
      window.URL.revokeObjectURL(url)
      document.body.removeChild(a)

      this.showMessage(`Export completed successfully! Downloaded ${this.selectedProducts.size} products.`, 'success')
    } catch (error) {
      this.showMessage(`Export failed: ${error.message}`, 'error')
    } finally {
      this.exportBtnTarget.disabled = false
    }
  }

  async exportRecentProducts() {
    const hours = parseInt(this.hoursSelectTarget.value)
    this.recentExportBtnTarget.disabled = true
    this.showMessage(`Generating export for products changed in last ${hours} hours... Please wait.`, 'info')

    try {
      const response = await fetch('/admin/product_data_transfer/export_recent', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ hours: hours })
      })

      if (response.status === 423) {
        this.showMessage('Another export is already in progress. Please wait.', 'error')
        this.recentExportBtnTarget.disabled = false
        return
      }

      if (!response.ok) {
        const error = await response.json()
        throw new Error(error.error || 'Export failed')
      }

      const blob = await response.blob()
      const contentDisposition = response.headers.get('Content-Disposition')
      const filenameMatch = contentDisposition?.match(/filename="?(.+?)"?$/i)
      const filename = filenameMatch ? filenameMatch[1] : 'product_export_recent.json.gz'

      const url = window.URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = filename
      document.body.appendChild(a)
      a.click()
      window.URL.revokeObjectURL(url)
      document.body.removeChild(a)

      this.showMessage(`Export completed successfully! Downloaded products changed in last ${hours} hours.`, 'success')
    } catch (error) {
      this.showMessage(`Export failed: ${error.message}`, 'error')
    } finally {
      this.recentExportBtnTarget.disabled = false
    }
  }

  showMessage(message, type = 'info') {
    const alertClasses = {
      success: 'bg-green-50 border-green-200 text-green-800',
      error: 'bg-red-50 border-red-200 text-red-800',
      info: 'bg-blue-50 border-blue-200 text-blue-800'
    }

    const iconNames = {
      success: 'check_circle',
      error: 'error',
      info: 'info'
    }

    this.messageContainerTarget.innerHTML = `
      <div class="border rounded-lg p-4 mb-4 ${alertClasses[type]}">
        <div class="flex items-center">
          <span class="material-icons text-sm mr-2">${iconNames[type]}</span>
          <span>${message}</span>
        </div>
      </div>
    `

    setTimeout(() => {
      this.messageContainerTarget.innerHTML = ''
    }, 5000)
  }
}
