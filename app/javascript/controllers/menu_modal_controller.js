import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    // Only the instance on the modal element should register global handlers
    this._keydownHandler = this._handleKeydown.bind(this);
  this._openForCreateHandler = this.openForCreate.bind(this);
    this._handleOpenEventHandler = this._handleOpenEvent.bind(this);

    document.addEventListener('keydown', this._keydownHandler);
    document.addEventListener('menu:item:create', this._openForCreateHandler);
    document.addEventListener('menu:item:open', this._handleOpenEventHandler);

    this._fetchInProgress = false;
    this._openingId = null;
  }

  disconnect() {
    if (this._keydownHandler) {
      document.removeEventListener('keydown', this._keydownHandler);
      this._keydownHandler = null;
    }
    if (this._openForCreateHandler) {
      document.removeEventListener('menu:item:create', this._openForCreateHandler);
      this._openForCreateHandler = null;
    }
    if (this._handleOpenEventHandler) {
      document.removeEventListener('menu:item:open', this._handleOpenEventHandler);
      this._handleOpenEventHandler = null;
    }
  }

  _handleKeydown(event) {
    if (event.key === 'Escape') {
      // Close the modal by dispatching native close action on the modal element
      if (this.element && !this.element.classList.contains('hidden')) {
        // Try to call closeModal on the menu-item-edit controller if present
        try {
          const ctrl = this.application.getControllerForElementAndIdentifier(this.element, 'menu-item-edit');
          if (ctrl && typeof ctrl.closeModal === 'function') {
            ctrl.closeModal(event);
            return;
          }
        } catch (e) {
          // ignore
        }
        // Fallback: hide element
        this.element.classList.add('hidden');
      }
    }
  }

  openForCreate(e) {
    const sectionId = e?.detail?.sectionId;
    // Find the form inside the modal and reset for creation
    const form = this.element.querySelector('form');
    if (form) {
      form.reset();
      form.action = '/admin/menu_bar_items';
      form.method = 'post';

      let sectionInput = form.querySelector('input[name="menu_bar_item[menu_bar_section_id]"]');
      if (!sectionInput) {
        sectionInput = document.createElement('input');
        sectionInput.type = 'hidden';
        sectionInput.name = 'menu_bar_item[menu_bar_section_id]';
        form.appendChild(sectionInput);
      }
      if (sectionId) sectionInput.value = sectionId;

      const idInput = form.querySelector('input[name="menu_bar_item[id]"]');
      if (idInput) idInput.remove();
    }

    // Show the modal
    this.element.classList.remove('hidden');
    const firstInput = this.element.querySelector('input, select, textarea');
    if (firstInput) firstInput.focus();
  }

  _handleOpenEvent(e) {
    const id = e?.detail?.id;
    if (!id) return;

    if (this._fetchInProgress && this._openingId === id) return;
    this._fetchInProgress = true;
    this._openingId = id;

    fetch(`/admin/menu_bar_items/${id}?modal=true`, {
      headers: { 'Accept': 'text/vnd.turbo-stream.html' },
      credentials: 'same-origin'
    })
      .then(response => response.text())
      .then(html => {
        if (html) {
          window.Turbo.renderStreamMessage(html);
          // After DOM replacement, try to open the replaced modal controller
          setTimeout(() => {
            try {
              const modalEl = document.getElementById('menu-item-edit-modal');
              if (!modalEl) return;
              const ctrl = this.application.getControllerForElementAndIdentifier(modalEl, 'menu-item-edit');
              if (ctrl) {
                if (typeof ctrl.findSortableInstances === 'function') ctrl.findSortableInstances();
                if (typeof ctrl.disableSortableInstances === 'function') ctrl.disableSortableInstances();
                if (ctrl.hasModalTarget) ctrl.modalTarget.classList.remove('hidden');
                const firstInput = modalEl.querySelector('input, select, textarea');
                if (firstInput) firstInput.focus();
              }
            } catch (e) {
              console.error('Error opening replaced modal controller', e);
            }
          }, 60);
        }
      })
      .catch(err => console.error('Failed to fetch modal content', err))
      .finally(() => {
        this._fetchInProgress = false;
        this._openingId = null;
      });
  }
}
