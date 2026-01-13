import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["container"];

  connect() {
    // Initialize top-level Sortable and nested sortables if a container is provided
    if (this.hasContainerTarget) {
      // leave Sortable creation to the existing menu_item_sort controller for now
    }
  }

  findSortableInstances() {
    const instances = [];
    try {
      const elements = document.querySelectorAll('[data-controller="menu-item-sort"]');
      elements.forEach(el => {
        try {
          const app = (window.Stimulus && window.Stimulus.application) ? window.Stimulus.application : window.Stimulus;
          const controller = app.getControllerForElementAndIdentifier(el, 'menu-item-sort');
          if (controller) {
            if (controller.topLevelSortable) instances.push(controller.topLevelSortable);
            if (controller.nestedSortables && Array.isArray(controller.nestedSortables)) instances.push(...controller.nestedSortables);
          }
        } catch (e) {
          // ignore
        }
      });
    } catch (e) {
      // ignore
    }
    return instances;
  }

  disableSortableInstances() {
    const items = this.findSortableInstances();
    items.forEach(sortable => {
      try { if (sortable && typeof sortable.option === 'function') sortable.option('disabled', true); } catch (e) {}
    });
    const handles = document.querySelectorAll('.parent-drag-handle, .child-drag-handle');
    handles.forEach(handle => {
      handle.classList.add('cursor-not-allowed', 'opacity-50', 'text-gray-300');
      handle.classList.remove('cursor-move', 'hover:text-gray-600');
    });
  }

  enableSortableInstances() {
    const items = this.findSortableInstances();
    items.forEach(sortable => {
      try { if (sortable && typeof sortable.option === 'function') sortable.option('disabled', false); } catch (e) {}
    });
    const handles = document.querySelectorAll('.parent-drag-handle, .child-drag-handle');
    handles.forEach(handle => {
      handle.classList.remove('cursor-not-allowed', 'opacity-50', 'text-gray-300');
      handle.classList.add('cursor-move', 'hover:text-gray-600');
    });
  }
}
