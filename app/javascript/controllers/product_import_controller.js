import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "form",
    "fileInput",
    "submitBtn",
    "progressContainer",
    "progressBar",
    "progressText",
    "importedCount",
    "updatedCount",
    "skippedCount",
    "errorsContainer",
    "errorsList",
    "messageContainer"
  ]

  static values = {
    resumeImport: Boolean
  }

  connect() {
    this.pollInterval = null

    if (this.hasResumeImportValue && this.resumeImportValue) {
      this.resumeExistingImport()
    }
  }

  disconnect() {
    this.stopPolling()
  }

  async resumeExistingImport() {
    try {
      const response = await fetch(
        '/admin/product_data_transfer/import_progress',
        {
          headers: {
            'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
          }
        }
      )

      if (!response.ok) {
        return
      }

      const data = await response.json()

      if (data.status === 'processing') {
        this.showProgressContainer()
        this.updateProgress(data)
        this.startPolling()
        this.submitBtnTarget.disabled = true
        this.showMessage('Resuming import in progress...', 'info')
      }
    } catch (error) {
      console.error('Failed to resume import:', error)
    }
  }

  fileSelected(event) {
    const file = event.target.files[0]
    if (!file) return

    if (!file.name.endsWith('.gz') && !file.name.endsWith('.json.gz')) {
      this.showMessage('Please select a valid .json.gz file', 'error')
      event.target.value = ''
    }
  }

  async submit(event) {
    event.preventDefault()

    const formData = new FormData(this.formTarget)
    this.submitBtnTarget.disabled = true
    this.showMessage('Uploading file and starting import...', 'info')

    try {
      const response = await fetch(this.formTarget.action, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: formData
      })

      if (!response.ok) {
        const error = await response.json()
        throw new Error(error.error || 'Import failed to start')
      }

      const data = await response.json()

      this.showMessage('Import started successfully!', 'success')
      this.showProgressContainer()
      this.checkProgress()
      this.startPolling()
    } catch (error) {
      this.submitBtnTarget.disabled = false
    }
  }

  startPolling() {
    this.pollInterval = setInterval(() => {
      this.checkProgress()
    }, 2000)
  }

  stopPolling() {
    if (this.pollInterval) {
      clearInterval(this.pollInterval)
      this.pollInterval = null
    }
  }

  async checkProgress() {
    try {
      const response = await fetch(
        '/admin/product_data_transfer/import_progress',
        {
          headers: {
            'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
          }
        }
      )

      if (!response.ok) {
        throw new Error('Failed to fetch progress')
      }

      const data = await response.json()
      this.updateProgress(data)

      if (data.status === 'completed' || data.status === 'error') {
        this.stopPolling()
        this.submitBtnTarget.disabled = false

        if (data.status === 'completed') {
          this.showMessage(data.message || 'Import completed successfully!', 'success')
        } else {
          this.showMessage(data.message || 'Import failed', 'error')
        }
      }
    } catch (error) {
      console.error('Progress check error:', error)
    }
  }

  updateProgress(data) {
    const { progress, total, imported_count, updated_count, skipped_count, errors } = data

    const percentage = total > 0 ? Math.round((progress / total) * 100) : 0
    this.progressBarTarget.style.width = `${percentage}%`
    this.progressTextTarget.textContent = `${progress} / ${total}`

    this.importedCountTarget.textContent = imported_count || 0
    this.updatedCountTarget.textContent = updated_count || 0
    this.skippedCountTarget.textContent = skipped_count || 0

    if (errors && errors.length > 0) {
      this.errorsContainerTarget.classList.remove('hidden')
      this.errorsListTarget.innerHTML = errors
        .map(error => `<li>${this.escapeHtml(error)}</li>`)
        .join('')
    } else {
      this.errorsContainerTarget.classList.add('hidden')
    }
  }

  showProgressContainer() {
    this.progressContainerTarget.classList.remove('hidden')
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

    if (type !== 'info') {
      setTimeout(() => {
        this.messageContainerTarget.innerHTML = ''
      }, 5000)
    }
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
