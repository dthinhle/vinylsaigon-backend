import { Controller } from "@hotwired/stimulus"
import TomSelect from "tom-select"

export default class extends Controller {
  static targets = ["bundleSection", "bundleItemsContainer", "bundleItem", "discountValueField", "maxDiscountField", "destroyField", "variantSelect"]

  static TOM_SELECT_INIT_DELAY = 100

  async connect() {
    this.bundleItemCount = this.bundleItemTargets.length
    this.initializeExistingSelects()
    await this.loadExistingVariants()
    this.toggleBundleSection()
  }

  toggleBundleSection(event) {
    const discountType = event?.target?.value || document.querySelector('select[name="promotion[discount_type]"]')?.value

    if (this.hasBundleSectionTarget) {
      if (discountType === 'bundle') {
        this.bundleSectionTarget.style.display = 'block'
        if (this.bundleItemTargets.length === 0) {
          this.addBundleItem()
          this.addBundleItem()
        }
      } else {
        this.bundleSectionTarget.style.display = 'none'
      }
    }

    if (this.hasMaxDiscountFieldTarget) {
      if (discountType === 'percentage') {
        this.maxDiscountFieldTarget.style.display = 'block'
      } else {
        this.maxDiscountFieldTarget.style.display = 'none'
      }
    }
  }

  initializeExistingSelects() {
    this.bundleItemTargets.forEach(item => {
      const variantSelect = item.querySelector('[data-bundle-promotion-target="variantSelect"]')
      if (variantSelect && !variantSelect.tomselect) {
        new TomSelect(variantSelect, {
          persist: false,
          create: false,
        })
      }
    })
  }

  loadExistingVariants() {
    const loadPromises = this.bundleItemTargets.map(async (item) => {
      const productSelect = item.querySelector('select[name*="[product_id]"]')
      const productId = productSelect?.value

      if (productId) {
        const variantSelect = item.querySelector('[data-bundle-promotion-target="variantSelect"]')
        const selectedVariantId = variantSelect?.value

        try {
          const response = await fetch(`/admin/products/${productId}/variants`)
          if (!response.ok) {
            throw new Error('Failed to fetch variants')
          }
          const data = await response.json()

          this.updateVariantSelect(variantSelect, data.variants || [])

          if (selectedVariantId && variantSelect.tomselect) {
            variantSelect.tomselect.setValue(selectedVariantId)
          }
        } catch (error) {
          console.error('Error loading variants:', error)
        }
      }
    })

    return Promise.all(loadPromises)
  }

  addBundleItem(event) {
    event?.preventDefault()

    const template = this.createBundleItemTemplate()
    this.bundleItemsContainerTarget.insertAdjacentHTML('beforeend', template)
    this.bundleItemCount++

    this.initializeTomSelect()
  }

  removeBundleItem(event) {
    event.preventDefault()

    const item = event.target.closest('[data-bundle-promotion-target="bundleItem"]')
    const destroyField = item.querySelector('[data-bundle-promotion-target="destroyField"]')

    if (destroyField && destroyField.value !== undefined) {
      destroyField.value = '1'
      item.style.display = 'none'
    } else {
      item.remove()
    }
  }

  async productChanged(event) {
    const productId = event.target.value
    const bundleItem = event.target.closest('[data-bundle-promotion-target="bundleItem"]')
    const variantSelect = bundleItem.querySelector('[data-bundle-promotion-target="variantSelect"]')

    if (!productId) {
      this.clearVariantSelect(variantSelect)
      return
    }

    try {
      const response = await fetch(`/admin/products/${productId}/variants`)
      if (!response.ok) {
        throw new Error('Failed to fetch variants')
      }
      const data = await response.json()

      this.updateVariantSelect(variantSelect, data.variants || [])
    } catch (error) {
      console.error('Error loading variants:', error)
      this.clearVariantSelect(variantSelect)
    }
  }

  clearVariantSelect(select) {
    if (select.tomselect) {
      select.tomselect.clearOptions()
      select.tomselect.addOption({ value: '', text: 'Any variant' })
      select.tomselect.setValue('')
    } else {
      select.innerHTML = '<option value="">Any variant</option>'
    }
  }

  updateVariantSelect(select, variants) {
    if (select.tomselect) {
      select.tomselect.clearOptions()
      select.tomselect.addOption({ value: '', text: 'Any variant' })
      variants.forEach(variant => {
        select.tomselect.addOption({ value: variant.id, text: variant.name })
      })
      select.tomselect.setValue('')
    } else {
      let options = '<option value="">Any variant</option>'
      variants.forEach(variant => {
        options += `<option value="${variant.id}">${variant.name}</option>`
      })
      select.innerHTML = options
    }
  }

  createBundleItemTemplate() {
    const timestamp = new Date().getTime()
    return `
      <div class="bundle-item bg-white border border-gray-300 rounded-lg p-4 flex flex-col gap-3" data-bundle-promotion-target="bundleItem">
        <input type="hidden" name="promotion[product_bundles_attributes][${timestamp}][_destroy]" value="false" data-bundle-promotion-target="destroyField">

        <div class="flex items-start justify-between">
          <h5 class="text-sm font-semibold text-gray-700">Bundle Item</h5>
          <button type="button" data-action="click->bundle-promotion#removeBundleItem" class="text-red-600 hover:text-red-800">
            <span class="material-icons text-lg">close</span>
          </button>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Product</label>
            <select name="promotion[product_bundles_attributes][${timestamp}][product_id]"
              class="w-full product-select-${timestamp}"
              data-controller="tom-select-remote"
              data-tom-select-remote-url-value="/admin/selectors/products"
              data-tom-select-remote-value-field-value="id"
              data-tom-select-remote-label-field-value="name"
              data-action="change->bundle-promotion#productChanged">
              <option value="">Select product</option>
            </select>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Variant (Optional)</label>
            <select name="promotion[product_bundles_attributes][${timestamp}][product_variant_id]"
              class="w-full variant-select-${timestamp}"
              data-bundle-promotion-target="variantSelect">
              <option value="">Any variant</option>
            </select>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Quantity</label>
            <input type="number" name="promotion[product_bundles_attributes][${timestamp}][quantity]"
              min="1" value="1"
              class="input input-bordered text-sm w-full px-3 py-2 rounded border border-gray-300 focus:ring-sky-500"
              placeholder="1">
          </div>
        </div>
      </div>
    `
  }

  initializeTomSelect() {
    setTimeout(() => {
      const bundleItems = this.bundleItemsContainerTarget.querySelectorAll('[data-bundle-promotion-target="bundleItem"]')
      bundleItems.forEach(item => {
        const variantSelect = item.querySelector('[data-bundle-promotion-target="variantSelect"]')
        if (variantSelect && !variantSelect.tomselect) {
          new TomSelect(variantSelect, {
            persist: false,
            create: false,
          })
        }
      })

      const selects = this.element.querySelectorAll('select[data-controller*="tom-select"]')
      selects.forEach(select => {
        if (!select.tomselect) {
          const event = new Event('turbo:load', { bubbles: true })
          select.dispatchEvent(event)
        }
      })
    }, this.constructor.TOM_SELECT_INIT_DELAY)
  }
}
