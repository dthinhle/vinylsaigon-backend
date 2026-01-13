import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sendPasswordResetButton"]

  sendPasswordReset(event) {
    event.preventDefault()

    const button = event.currentTarget
    const url = button.dataset.url
    const csrfToken = document.querySelector('meta[name="csrf-token"]').content

    // Disable button and show loading state
    button.disabled = true
    const originalText = button.querySelector('span:last-child').textContent
    button.querySelector('span:last-child').textContent = 'Sending...'

    fetch(url, {
      method: 'POST',
      headers: {
        'X-CSRF-Token': csrfToken,
        'Accept': 'application/json'
      }
    })
      .then(response => {
        if (response.ok) {
          return response.json()
        }
        throw new Error('Network response was not ok')
      })
      .then(data => {
        // Show success message via toast event
        this.dispatchToast('Password reset email sent successfully', 'success')

        // Re-enable button
        button.disabled = false
        button.querySelector('span:last-child').textContent = originalText
      })
      .catch(error => {
        // Show error message via toast event
        this.dispatchToast('Failed to send password reset email', 'error')

        // Re-enable button
        button.disabled = false
        button.querySelector('span:last-child').textContent = originalText
      })
  }

  dispatchToast(message, type) {
    const event = new CustomEvent('toast:show', {
      detail: { message, type },
      bubbles: true
    })
    document.dispatchEvent(event)
  }
}
