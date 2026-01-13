import { Controller } from "@hotwired/stimulus"

// Custom toast controller for top-right notifications
export default class extends Controller {
  static targets = ["container"]

  connect() {
    this.toasts = []
    // Listen for custom toast events
    this._boundHandleToast = this.handleToastEvent.bind(this)
    document.addEventListener("toast:show", this._boundHandleToast)
  }

  disconnect() {
    if (this._boundHandleToast) {
      document.removeEventListener("toast:show", this._boundHandleToast)
      this._boundHandleToast = null
    }
  }

  handleToastEvent(event) {
    const { message, type } = event.detail
    this.show(message, type)
  }

  show(message, type = "success") {
    const toast = this.createToast(message, type)
    this.containerTarget.appendChild(toast)
    this.toasts.push(toast)

    // Auto remove after 3 seconds
    setTimeout(() => {
      this.removeToast(toast)
    }, 3000)
  }

  createToast(message, type) {
    const toast = document.createElement("div")
    toast.className = `fixed top-18 right-4 z-50 rounded-lg shadow-lg transform transition-all duration-300 translate-x-full`

    const bgColor = type === "success" ? "bg-green-500" : "bg-red-500"
    // const textColor = "text-white"
    const icon = type === "success" ? "check_circle" : "error"

    toast.innerHTML = `
      <div class="bg-gray-50 text-gray-950 text-sm p-3 rounded-lg max-w-lg flex items-center justify-between">
        <div class="p-1 mr-2 ${bgColor} rounded">
          <span class="flex! material-icons size-7 text-lg! text-white justify-center">${icon}</span>
        </div>
        <span>${message}</span>
        <button class="ml-4 text-gray-700 hover:text-gray-900" onclick="this.parentElement.parentElement.remove()">×</button>
      </div>
    `

    // Animate in
    setTimeout(() => {
      toast.classList.remove("translate-x-full")
    }, 10)

    return toast
  }

  removeToast(toast) {
    toast.classList.add("translate-x-full")
    setTimeout(() => {
      if (toast.parentElement) {
        toast.parentElement.removeChild(toast)
      }
      this.toasts = this.toasts.filter(t => t !== toast)
    }, 300)
  }

  // Listen for turbo responses with flash
  handleTurboResponse(event) {
    const response = event.detail?.fetchResponse
    if (response?.json) {
      response.json().then(data => {
        if (data.flash?.notice) {
          this.show(data.flash.notice, "success")
        }
        if (data.flash?.alert) {
          this.show(data.flash.alert, "error")
        }
      })
    }
  }
}
