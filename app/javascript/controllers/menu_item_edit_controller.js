import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["modal", "parentSelect", "parentIndicator"];
  static values = { id: Number };

  connect() {
    // Store references to Sortable instances - will be populated when modal opens
    this.sortableInstances = [];
  }

  disconnect() {
    // No global listeners here; modal-level global handlers live in menu_modal_controller
  }

  onParentChange(event) {
    const selectedOption = event.target.selectedOptions[0];
    const selectedText = selectedOption ? selectedOption.text : '';
    this.updateParentIndicator(selectedText);
  }

  updateParentIndicator(parentText) {
    if (!this.hasParentIndicatorTarget) return;
    this.parentIndicatorTarget.innerHTML = '';

    if (parentText && parentText !== '(Top level)') {
      const indicator = document.createElement('div');
      indicator.className = 'parent-indicator selected-parent mt-2 p-2 bg-blue-50 border-blue-200 rounded text-sm text-blue-700';
      indicator.innerHTML = `
        <span class="font-medium">Selected Parent:</span>
        <span class="parent-indicator-value">${parentText}</span>
      `;
      this.parentIndicatorTarget.appendChild(indicator);
    } else if (parentText === '(Top level)') {
      const indicator = document.createElement('div');
      indicator.className = 'parent-indicator top-level mt-2 p-2 bg-gray-50 border border-gray-200 rounded text-sm text-gray-700';
      indicator.innerHTML = `
        <span class="font-medium">Selected Parent:</span>
        <span class="parent-indicator-value">Top Level</span>
      `;
      this.parentIndicatorTarget.appendChild(indicator);
    }
  }

  open(event) {
    event.preventDefault();
    event.stopPropagation();
    const readonly = event.currentTarget?.dataset?.readonly === "true";
    this.readonly = readonly;

    this.findSortableInstances();
    this.disableSortableInstances();

    if (this.hasModalTarget) this.modalTarget.classList.remove('hidden');

    const form = this.hasModalTarget ? this.modalTarget.querySelector('form') : null;
    if (form) {
      const fields = form.querySelectorAll('input, select, textarea');
      fields.forEach(field => {
        if (readonly) {
          field.setAttribute('readonly', 'readonly');
          field.setAttribute('disabled', 'disabled');
        } else {
          field.removeAttribute('readonly');
          field.removeAttribute('disabled');
        }
      });
    }

    const firstInput = this.hasModalTarget ? this.modalTarget.querySelector('input, select, textarea') : null;
    if (firstInput && !readonly) firstInput.focus();
  }

  openForCreate(e) {
    const sectionId = e?.detail?.sectionId;
    if (!this.hasModalTarget) return;

    const form = this.modalTarget.querySelector('form');
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

    this.findSortableInstances();
    this.disableSortableInstances();
    this.modalTarget.classList.remove('hidden');

    const firstInput = this.modalTarget.querySelector('input, select, textarea');
    if (firstInput) firstInput.focus();
  }

  requestOpen(event) {
    event.preventDefault();
    event.stopPropagation();
    const id = this.element.dataset.menuItemEditId || this.element.dataset.menuItemEditIdValue || null;
    const readonly = event.currentTarget?.dataset?.readonly === 'true';
    document.dispatchEvent(new CustomEvent('menu:item:open', { detail: { id, readonly } }));
  }

  close(event) {
    event?.preventDefault();
    event?.stopPropagation();
    this.closeModal(event);
  }

  closeModal(event) {
    if (this.hasModalTarget) {
      this.modalTarget.classList.add('hidden');

      // Reset any image-preview controllers inside the modal so selected
      // files/previews do not persist when the modal is reopened.
      try {
        const imgControllers = this.modalTarget.querySelectorAll('[data-controller*="image-preview"]');
        imgControllers.forEach(el => {
          try {
            const app = (window.Stimulus && window.Stimulus.application) ? window.Stimulus.application : window.Stimulus;
            const ctrl = app.getControllerForElementAndIdentifier(el, 'image-preview');
            if (ctrl && typeof ctrl.resetSelection === 'function') ctrl.resetSelection();
          } catch (e) { /* ignore per-controller errors */ }
        });
      } catch (e) { /* ignore */ }
    }
    this.enableSortableInstances();
    this.resetErrorStates();
  }

  showToast = (message, type = "success") => {
    document.dispatchEvent(new CustomEvent("toast:show", { detail: { message, type } }));
  }

  // Find all sortable instances on the page
  findSortableInstances() {
    this.sortableInstances = [];
    try {
      const elements = document.querySelectorAll('[data-controller="menu-item-sort"]');
      elements.forEach(element => {
        try {
          const controller = this.application.getControllerForElementAndIdentifier(element, 'menu-item-sort');
          if (controller) {
            if (controller.topLevelSortable) this.sortableInstances.push(controller.topLevelSortable);
            if (controller.nestedSortables && Array.isArray(controller.nestedSortables)) this.sortableInstances.push(...controller.nestedSortables);
          }
        } catch (e) {
          // ignore
        }
      });
    } catch (error) {
      console.warn('Error finding sortable instances:', error);
    }
  }

  disableSortableInstances() {
    this.sortableInstances.forEach(sortable => {
      try { if (sortable && typeof sortable.option === 'function') sortable.option('disabled', true); } catch (e) {}
    });
    try {
      const dragHandles = document.querySelectorAll('.parent-drag-handle, .child-drag-handle');
      dragHandles.forEach(handle => {
        handle.classList.add('cursor-not-allowed', 'opacity-50', 'text-gray-300');
        handle.classList.remove('cursor-move', 'hover:text-gray-600');
      });
    } catch (e) { /* ignore */ }
  }

  enableSortableInstances() {
    this.sortableInstances.forEach(sortable => {
      try { if (sortable && typeof sortable.option === 'function') sortable.option('disabled', false); } catch (e) {}
    });
    this.sortableInstances = [];
    try {
      const dragHandles = document.querySelectorAll('.parent-drag-handle, .child-drag-handle');
      dragHandles.forEach(handle => {
        handle.classList.remove('cursor-not-allowed', 'opacity-50', 'text-gray-300');
        handle.classList.add('cursor-move', 'hover:text-gray-600');
      });
    } catch (e) { /* ignore */ }
  }

  // Error helpers
  highlightErrorFields() {
    if (!this.hasModalTarget) return;
    const errorFields = this.modalTarget.querySelectorAll('.field_with_errors, input.field_with_errors, select.field_with_errors, textarea.field_with_errors');
    errorFields.forEach(field => field.classList.add('border-red-500', 'ring-2', 'ring-red-200'));

    const allInputs = this.modalTarget.querySelectorAll('input, select, textarea');
    allInputs.forEach(input => {
      const nextElement = input.nextElementSibling;
      if (nextElement && nextElement.classList && nextElement.classList.contains('text-red-600')) {
        input.classList.add('border-red-500', 'ring-2', 'ring-red-200');
      }
      input.addEventListener('input', this.clearErrorOnInput.bind(this), { once: true });
      input.addEventListener('change', this.clearErrorOnChange.bind(this), { once: true });
    });
  }

  clearErrorOnInput(event) {
    const input = event.target;
    input.classList.remove('border-red-500', 'ring-2', 'ring-red-200');
    const nextElement = input.nextElementSibling;
    if (nextElement && nextElement.classList && nextElement.classList.contains('text-red-600')) nextElement.remove();
  }

  clearErrorOnChange(event) {
    const input = event.target;
    input.classList.remove('border-red-500', 'ring-2', 'ring-red-200');
    const nextElement = input.nextElementSibling;
    if (nextElement && nextElement.classList && nextElement.classList.contains('text-red-600')) nextElement.remove();
  }

  resetErrorStates() {
    if (!this.hasModalTarget) return;
    const errorFields = this.modalTarget.querySelectorAll('.field_with_errors, input.field_with_errors, select.field_with_errors, textarea.field_with_errors, .border-red-500, .ring-red-200');
    errorFields.forEach(field => field.classList.remove('border-red-500', 'ring-2', 'ring-red-200'));
    const errorMessages = this.modalTarget.querySelectorAll('p.text-red-600, .error');
    errorMessages.forEach(message => message.remove());
  }
}
