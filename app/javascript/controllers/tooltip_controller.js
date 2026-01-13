import { Controller } from "@hotwired/stimulus"
import { computePosition, flip, shift, offset } from "@floating-ui/dom"

export default class extends Controller {
  static values = {
    text: String,
    position: { type: String, default: "top" }
  }

  connect() {
    this.tooltip = null
    this.boundShow = this.show.bind(this)
    this.boundHide = this.hide.bind(this)
    this.element.addEventListener("mouseenter", this.boundShow)
    this.element.addEventListener("mouseleave", this.boundHide)
    this.element.addEventListener("focus", this.boundShow)
    this.element.addEventListener("blur", this.boundHide)
  }

  disconnect() {
    this.hide()
    this.element.removeEventListener("mouseenter", this.boundShow)
    this.element.removeEventListener("mouseleave", this.boundHide)
    this.element.removeEventListener("focus", this.boundShow)
    this.element.removeEventListener("blur", this.boundHide)
  }

  show() {
    if (this.tooltip) return

    this.tooltip = document.createElement("div")
    this.tooltip.className = "tooltip-popup"
    this.tooltip.textContent = this.textValue
    this.tooltip.setAttribute("role", "tooltip")

    document.body.appendChild(this.tooltip)

    this.updatePosition()
  }

  hide() {
    if (this.tooltip) {
      this.tooltip.remove()
      this.tooltip = null
    }
  }

  async updatePosition() {
    if (!this.tooltip) return

    const { x, y } = await computePosition(this.element, this.tooltip, {
      placement: this.positionValue,
      middleware: [
        offset(8),
        flip(),
        shift({ padding: 5 })
      ]
    })

    Object.assign(this.tooltip.style, {
      left: `${x}px`,
      top: `${y}px`
    })
  }
}
