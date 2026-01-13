import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["container"]

  showToast = (message, type = "success") => {
    document.dispatchEvent(new CustomEvent("toast:show", {
      detail: { message, type }
    }));
  }

  computeState() {
    const state = {};
    try {
      const sections = document.querySelectorAll('[data-section-id]');
      sections.forEach(section => {
        const containers = Array.from(section.querySelectorAll('[data-menu-container="true"]:not([data-menu-container="true"] [data-menu-container="true"])'));
        const leafItems = Array.from(section.querySelectorAll('[data-menu-item="true"]:not([data-menu-container="true"] [data-menu-item="true"])'));

        containers.forEach((container, containerIdx) => {
          const parentItem = container.querySelector('[data-menu-item="true"]');
          if (!parentItem) return;
          const parentId = parentItem.getAttribute('data-id');

          const parentParentId = this.getParentIdFromElement(parentItem);

          state[parentId] = { parent_id: parentParentId === null ? null : String(parentParentId), position: containerIdx + 1, depth: 0 };

          const childList = container.querySelector('[data-child-list]');
          if (childList) {
            const childItems = Array.from(childList.querySelectorAll('[data-menu-item="true"]'));
            childItems.forEach((childItem, childIdx) => {
              const cid = childItem.getAttribute('data-id');

              state[cid] = { parent_id: String(parentId), position: childIdx + 1, depth: 1 };
            });
          }
        });

        const containerCount = containers.length;
        leafItems.forEach((item, idx) => {
          const id = item.getAttribute('data-id');
          const parentId = this.getParentIdFromElement(item);

          const depth = (this.getParentIdFromElement(item) === null) ? 0 : 1;
          state[id] = { parent_id: parentId === null ? null : String(parentId), position: containerCount + idx + 1, depth };
        });
      });
    } catch (e) {

    }
    return state;
  }
  getParentIdFromElement(element) {
    try {
      const childList = element.closest('[data-child-list]');
      if (childList) {
        const container = childList.closest('[data-menu-container="true"]');
        if (container) {
          const parentItem = container.querySelector('[data-menu-item="true"]');
          if (parentItem) return parentItem.getAttribute('data-id');
        }
      }

      const container = element.closest('[data-menu-container="true"]');
      if (container) {
        const containerParent = container.parentElement && container.parentElement.closest && container.parentElement.closest('[data-menu-container="true"]');
        if (containerParent) {
          const parentItem = containerParent.querySelector('[data-menu-item="true"]');
          if (parentItem) return parentItem.getAttribute('data-id');
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  onSortStart(event) {
    try {
      this._preSortState = this.computeState();
      if (event && event.item) {
        this._dragOriginalContext = {
          originalParent: event.from || (event.item.parentElement || null),
          originalNextSibling: event.item.nextSibling || null,
          wasContainer: event.item.matches && event.item.matches('[data-menu-container="true"]'),
          childrenCount: (event.item.querySelector ? event.item.querySelectorAll('[data-child-list] > [data-menu-item="true"]').length : 0)
        };
      } else {
        this._dragOriginalContext = null;
      }
    } catch (e) {
    }
  }

  syncPositionsFromServer = (itemsArray) => {
    if (!Array.isArray(itemsArray)) {
      console.warn("[menu-item-sort] syncPositionsFromServer: itemsArray is not an array");
      return 0;
    }

    let updatedCount = 0;
    const missing = [];
    itemsArray.forEach(item => {
      try {
        const { id, position } = item;
        const element = document.querySelector(`[data-id="${id}"]`);
        if (!element) { missing.push(id); return; }

        try { element.dataset.position = String(position); } catch (e) {}

        if (item.section_id !== undefined && item.section_id !== null) {
          try {
            const wrapper = element.closest('[data-menu-container="true"]') || element;
            if (wrapper) wrapper.setAttribute('data-section-id', String(item.section_id));
            element.setAttribute('data-section-id', String(item.section_id));
          } catch (e) { }
        }

        const parentId = item.parent_id === null || item.parent_id === undefined ? null : String(item.parent_id);
        if (parentId === null) {
          try {
            if (element.hasAttribute('data-parent-id')) element.removeAttribute('data-parent-id');
            delete element.dataset.parentId;
          } catch (e) {}
        } else {
          try {
            element.setAttribute('data-parent-id', parentId);
            element.dataset.parentId = parentId;
          } catch (e) {}
        }

        if (item.depth !== undefined) {
          const clamped = item.depth === 0 ? 0 : 1;
          try { element.dataset.depth = String(clamped); } catch (e) {}
        }

        if (!element.dataset.depth) {
          const pidAttr = element.getAttribute('data-parent-id');
            try { element.dataset.depth = (pidAttr === null || pidAttr === '' ? '0' : '1'); } catch (e) {}
        }

        if (parentId === null && !element.closest('[data-menu-container="true"]')) {
          try { this.ensureParentContainerStructure(element); } catch (e) {}
          try { this.reinitializeAllSortables(); } catch (e) {}
        }
        updatedCount++;
      } catch (rowErr) {
        console.debug('[menu-item-sort] sync row error', rowErr);
      }
    });

    // Single pass normalization after all updates (prevents intermediate flicker)
    try { this.ensureChildIndentation(); } catch (e) {}
    try { this.assignHandleByDepth(); } catch (e) {}
    if (missing.length) {
      try { console.debug('[menu-item-sort] missing DOM ids during sync (likely removed/promoted):', missing); } catch (e) {}
    }

    return updatedCount;
  }

  connect() {
    if (!this.containerTarget) {
      console.error("[menu-item-sort] containerTarget missing");
      return;
    }

    this._handleMousedown = (ev) => {
      try {
        const handle = ev.target.closest && ev.target.closest('.parent-drag-handle, .child-drag-handle');
        if (!handle) return;
        const active = document.activeElement;
        if (!active) return;
        const tag = (active.tagName || '').toUpperCase();
        if (tag === 'INPUT' || tag === 'TEXTAREA' || active.isContentEditable) {
          try { active.blur(); } catch (e) { }
        }
      } catch (e) { }
    };
    try { this.containerTarget.addEventListener('mousedown', this._handleMousedown, true); } catch (e) { }

    if (!window.__menuItemSortMousedownGuardRegistered) {
      window.__menuItemSortMousedownGuardRegistered = true;
      window.__menuItemSortMousedownGuard = function(ev) {
        try {
          const handle = ev.target.closest && ev.target.closest('.parent-drag-handle, .child-drag-handle');
          if (!handle) return;
          const active = document.activeElement;
          if (!active) return;
          const tag = (active.tagName || '').toUpperCase();
          if (tag === 'INPUT' || tag === 'TEXTAREA' || active.isContentEditable) {
            try { active.blur(); } catch (e) { }
          }
        } catch (e) { }
      };
      document.addEventListener('mousedown', window.__menuItemSortMousedownGuard, true);
    }

    this.reinitializeAllSortables();

    if (!window.__menuItemSortGlobalTurboHandlerRegistered) {
      const globalHandler = () => {
        setTimeout(() => {
          try {
            const elements = document.querySelectorAll('[data-controller="menu-item-sort"]');
            elements.forEach(el => {
              try {
                const app = (window.Stimulus && window.Stimulus.application) ? window.Stimulus.application : window.Stimulus;
                const controller = app.getControllerForElementAndIdentifier(el, 'menu-item-sort');
                if (controller && typeof controller.reinitializeAllSortables === 'function') {
                  controller.reinitializeAllSortables();
                } else if (controller && typeof controller.initializeNestedSortables === 'function') {
                  controller.initializeNestedSortables();
                }
              } catch (e) {

              }
            });

          } catch (e) {
            console.error("[menu-item-sort] Error re-initializing nested sortables", e);
          }
        }, 0);
      };
      document.addEventListener("turbo:before-stream-render", globalHandler);
      document.addEventListener("turbo:frame-render", globalHandler);
      window.__menuItemSortGlobalTurboHandlerRegistered = true;
      window.__menuItemSortGlobalTurboHandler = globalHandler;
    }
  }

  reinitializeAllSortables() {
    try {
      if (this.topLevelSortable) { try { this.topLevelSortable.destroy(); } catch (e) {} this.topLevelSortable = null; }
      if (this.nestedSortables && Array.isArray(this.nestedSortables)) {
        this.nestedSortables.forEach(s => { try { s.destroy(); } catch (e) {} });
        this.nestedSortables = [];
      }
    } catch (e) { }

    try {
      this.topLevelSortable = Sortable.create(this.containerTarget, {
        animation: 500,
        swapThreshold: 0.2,
        invertSwap: true,
        handle: '.parent-drag-handle',
        draggable: '[data-menu-container="true"]',
        onStart: this.onSortStart.bind(this),
        onEnd: this.onSortEnd.bind(this),
        group: { name: 'menu-items', pull: true, put: true }
      });
    } catch (e) { }
    this.initializeNestedSortables();

    try { this.assignHandleByDepth(); } catch (e) { }
    try { this.ensureChildIndentation(); } catch (e) { }
  }

  ensureParentContainerStructure(itemEl) {
    try {
      if (!itemEl) return;
      const existingContainer = itemEl.closest('[data-menu-container="true"]');
      if (existingContainer && existingContainer.querySelector('[data-menu-item="true"]') === itemEl) return;
      const container = document.createElement('div');
      container.setAttribute('data-menu-container', 'true');
      const childList = document.createElement('div');
      childList.setAttribute('data-child-list', '');
      if (itemEl.parentNode) itemEl.parentNode.insertBefore(container, itemEl);
      container.appendChild(itemEl);
      container.appendChild(childList);
    } catch (e) { }
  }

  ensureChildIndentation() {
    try {
      const allItems = this.containerTarget.querySelectorAll('[data-menu-item="true"]');
      allItems.forEach(el => {
        const parentIdAttr = el.getAttribute('data-parent-id');
        const depth = (parentIdAttr === null || parentIdAttr === '') ? 0 : 1;
        if (el.getAttribute('data-depth') !== String(depth)) {
          try { el.setAttribute('data-depth', String(depth)); el.dataset.depth = String(depth); } catch (e) {}
        }
        try { el.style.marginLeft = depth === 0 ? '0px' : '24px'; } catch (e) {}
      });
    } catch (e) { }
  }

  assignHandleByDepth() {
    try {
      const allItems = this.containerTarget.querySelectorAll('[data-menu-item="true"]');
      allItems.forEach(item => {

        let parentId = item.getAttribute('data-parent-id');
        if (parentId === '' || parentId === undefined) parentId = null;

        if (parentId === null) {
          const inferred = this.getParentIdFromElement(item);
          if (inferred) parentId = inferred;
        }

        const handle = item.querySelector('.parent-drag-handle, .child-drag-handle');
        if (!handle) return;
        if (parentId === null) {

            if (!handle.classList.contains('parent-drag-handle')) {
              handle.classList.remove('child-drag-handle');
              handle.classList.add('parent-drag-handle');
              try { handle.setAttribute('aria-label', 'Drag to reorder parent item'); } catch (e) {}
            }
        } else {

            if (!handle.classList.contains('child-drag-handle')) {
              handle.classList.remove('parent-drag-handle');
              handle.classList.add('child-drag-handle');
              try { handle.setAttribute('aria-label', 'Drag to reorder child item'); } catch (e) {}
            }
        }
      });
    } catch (e) { }
  }

  initializeNestedSortables() {

    if (this.nestedSortables && Array.isArray(this.nestedSortables)) {
      this.nestedSortables.forEach(s => {
        try { s.destroy(); } catch (e) { }
      });
    }

    this.nestedSortables = [];

    const containers = this.containerTarget.querySelectorAll('[data-menu-container="true"]');

    containers.forEach(container => {

      const childList = container.querySelector('[data-child-list]');
      if (childList) {
        const nestedSortable = Sortable.create(childList, {
          animation: 500,
          swapThreshold: 0.2,
          invertSwap: true,
          handle: ".child-drag-handle",
          draggable: '[data-menu-item="true"], [data-menu-container="true"]',
          group: {
            name: "menu-items",
          },
          onStart: this.onSortStart.bind(this),
          onEnd: this.onSortEnd.bind(this),
          onAdd: (evt) => {
            try {
              const itemEl = evt.item.closest('[data-menu-item="true"]') || evt.item;
              const parentContainer = childList.closest('[data-menu-container="true"]');
              const parentItem = parentContainer ? parentContainer.querySelector('[data-menu-item="true"]') : null;
              if (parentItem) {

                this.ensureParentContainerStructure(parentItem);
              }

              const parentId = parentItem && parentItem.getAttribute('data-id');
              if (parentId && itemEl) {
                try { itemEl.setAttribute('data-parent-id', parentId); itemEl.dataset.parentId = parentId; } catch (e) {}
              }
              this.ensureChildIndentation();

              try { this.assignHandleByDepth(); } catch (e) {}
            } catch (e) { }
          },
          onUpdate: () => {
            try { this.ensureChildIndentation(); } catch (e) {}
            try { this.assignHandleByDepth(); } catch (e) {}
          }
        });
        this.nestedSortables.push(nestedSortable);
      }
    });

    this.ensureChildIndentation();
    try { this.assignHandleByDepth(); } catch (e) {}
  }

  disconnect() {

    if (this.topLevelSortable) {
      try { this.topLevelSortable.destroy(); } catch (e) { }
    }
    if (this.nestedSortables) {
      this.nestedSortables.forEach(sortable => {
        try { sortable.destroy(); } catch (e) { }
      });
    }

    if (this._turboStreamHandler) {
      document.removeEventListener("turbo:before-stream-render", this._turboStreamHandler);
      document.removeEventListener("turbo:frame-render", this._turboStreamHandler);
      this._turboStreamHandler = null;
    }
  }

  async onSortEnd(event) {
    try {
      const movedEl = event && event.item ? event.item : null;
      if (movedEl && (movedEl.matches && movedEl.matches('[data-menu-container="true"]')) || (this._dragOriginalContext && this._dragOriginalContext.wasContainer)) {
        const isNowInChildList = movedEl.parentElement && movedEl.parentElement.hasAttribute('data-child-list');

        const hadChildren = (this._dragOriginalContext && typeof this._dragOriginalContext.childrenCount === 'number')
          ? this._dragOriginalContext.childrenCount > 0
          : (!!movedEl.querySelector && !!movedEl.querySelector('[data-child-list] > [data-menu-item="true"]'));
        if (isNowInChildList && hadChildren) {
          const destinationChildList = movedEl.parentElement;
          const destinationParentContainer = destinationChildList.closest('[data-menu-container="true"]');
            const destinationParentItem = destinationParentContainer ? destinationParentContainer.querySelector('[data-menu-item="true"]') : null;
          const destinationParentName = destinationParentItem
            ? (
              destinationParentItem.getAttribute('data-item-name') ||
              destinationParentItem.querySelector('.font-medium')?.textContent.trim() ||
              'mục đã chọn'
            )
            : 'mục đã chọn';

          const confirmMsg = `Tất cả mục con sẽ trở thành con của mục ${destinationParentName}. Tiếp tục?`;
          if (!window.confirm(confirmMsg)) {
            try {
              if (this._dragOriginalContext && this._dragOriginalContext.originalParent) {
                if (this._dragOriginalContext.originalNextSibling) {
                  this._dragOriginalContext.originalParent.insertBefore(movedEl, this._dragOriginalContext.originalNextSibling);
                } else {
                  this._dragOriginalContext.originalParent.appendChild(movedEl);
                }
              }
            } catch (revertErr) { }
            try { this.reinitializeAllSortables(); } catch (e) { }
            return;
          }

          try {
            const childList = movedEl.querySelector('[data-child-list]');
            const parentItemInside = movedEl.querySelector('[data-menu-item="true"]');
            const destinationParentId = destinationParentItem ? destinationParentItem.getAttribute('data-id') : null;
            const children = childList ? Array.from(childList.querySelectorAll(':scope > [data-menu-item="true"]')) : [];

            if (parentItemInside) {
              const handle = parentItemInside.querySelector('.parent-drag-handle');
              if (handle) {
                handle.classList.remove('parent-drag-handle');
                handle.classList.add('child-drag-handle');
                try { handle.setAttribute('aria-label', 'Drag to reorder child item'); } catch (e) {}
              }
              if (destinationParentId) {
                parentItemInside.setAttribute('data-parent-id', destinationParentId);
                parentItemInside.dataset.parentId = destinationParentId;
              }
              parentItemInside.dataset.depth = '1';
              movedEl.parentNode.insertBefore(parentItemInside, movedEl);
            }

            if (children.length && destinationChildList) {
              children.forEach(ci => {
                if (destinationParentId) {
                  ci.setAttribute('data-parent-id', destinationParentId);
                  ci.dataset.parentId = destinationParentId;
                }
                ci.dataset.depth = '1';
                destinationChildList.insertBefore(ci, movedEl);
              });
            }

            try { movedEl.remove(); } catch (e) { }


            try { this.reinitializeAllSortables(); } catch (e) { }
            try { this.ensureChildIndentation(); } catch (e) { }
            try { this.assignHandleByDepth(); } catch (e) { }

          } catch (flattenErr) {
            console.error('[menu-item-sort] Error flattening children during demotion', flattenErr);
          }
        }
      }
    } catch (confirmErr) {
    }

    try {
      const movedNode = event && event.item ? event.item : null;
      if (movedNode) {
        const menuItemEl = (movedNode.closest && movedNode.closest('[data-menu-item="true"]')) || movedNode;
        const movedId = menuItemEl && menuItemEl.getAttribute && menuItemEl.getAttribute('data-id');
        if (movedId) {
          const derivedParent = this.getParentIdFromElement(menuItemEl);
          const wrapper = document.getElementById(`menu_item_${movedId}`) || (menuItemEl.closest && menuItemEl.closest('[id^="menu_item_"]')) || menuItemEl;
          if (derivedParent === null) {
            try { wrapper.style.marginLeft = '0px'; } catch (e) {}
            if (menuItemEl.hasAttribute && menuItemEl.hasAttribute('data-parent-id')) {
              try { menuItemEl.removeAttribute('data-parent-id'); } catch (e) {}
              try { delete menuItemEl.dataset.parentId; } catch (e) {}
            }

            try {
              const topLevel = this.containerTarget;
              if (topLevel && wrapper && topLevel.contains && !topLevel.contains(wrapper)) {

                const posAttr = menuItemEl.getAttribute && menuItemEl.getAttribute('data-position');
                let insertBefore = null;
                if (posAttr) {
                  const desiredIndex = Math.max(0, Number(posAttr) - 1);
                  const topChildren = Array.from(topLevel.querySelectorAll(':scope > [data-menu-container="true"], :scope > [data-menu-item="true"]'));
                  if (desiredIndex < topChildren.length) insertBefore = topChildren[desiredIndex];
                }
                try {
                  if (insertBefore) topLevel.insertBefore(wrapper, insertBefore);
                  else topLevel.appendChild(wrapper);
                } catch (e) { }
              }
            } catch (e) {}

            try {
              const childHandle = wrapper.querySelector && wrapper.querySelector('.child-drag-handle');
              if (childHandle) {
                childHandle.classList.remove('child-drag-handle');
                childHandle.classList.add('parent-drag-handle');

                try { childHandle.setAttribute('aria-label', 'Drag to reorder parent item'); } catch (e) {}
              }
            } catch (e) {}

            try {
              const coreItem = wrapper.querySelector('[data-menu-item="true"]') || menuItemEl;
              this.ensureParentContainerStructure(coreItem);
              this.reinitializeAllSortables();
            } catch (e) { }
          } else {

            const margin = (derivedParent === null) ? '0px' : `${1 * 24}px`;
            try { wrapper.style.marginLeft = margin; } catch (e) {}

            try {
              const parentEl = document.querySelector(`[data-id="${derivedParent}"]`);
              if (parentEl) {
                this.ensureParentContainerStructure(parentEl);
              }
            } catch (e) { }

            try {
              const parentHandle = wrapper.querySelector && wrapper.querySelector('.parent-drag-handle');
              if (parentHandle) {
                parentHandle.classList.remove('parent-drag-handle');
                parentHandle.classList.add('child-drag-handle');
                try { parentHandle.setAttribute('aria-label', 'Drag to reorder child item'); } catch (e) {}
              }
            } catch (e) { }
          }
        }
      }
    } catch (e) {

    }
    const sections = document.querySelectorAll("[data-section-id]");
    const payload = [];

    sections.forEach(section => {

      const containers = Array.from(section.querySelectorAll('[data-menu-container="true"]:not([data-menu-container="true"] [data-menu-container="true"])'));
      const leafItems = Array.from(section.querySelectorAll('[data-menu-item="true"]:not([data-menu-container="true"] [data-menu-item="true"])'));


      containers.forEach((container, containerIdx) => {

        const parentItem = container.querySelector('[data-menu-item="true"]');
        if (!parentItem) return;

        const parentId = parentItem.getAttribute("data-id");

        const parentParentId = this.getParentIdFromElement(parentItem);

        const sectionAncestor = container.closest('[data-section-id]');
        const sectionId = sectionAncestor ? sectionAncestor.getAttribute('data-section-id') : null;

        payload.push({
          id: parentId,
          parent_id: parentParentId === null ? null : String(parentParentId),
          position: containerIdx + 1,
          depth: 0,
          section_id: sectionId
        });


        const childList = container.querySelector('[data-child-list]');
        if (childList) {
          const childItems = Array.from(childList.querySelectorAll('[data-menu-item="true"]'));
          childItems.forEach((childItem, childIdx) => {
            payload.push({
              id: childItem.getAttribute("data-id"),
              parent_id: String(parentId),
              position: childIdx + 1,
              depth: 1,
              section_id: sectionId
            });
          });
        }
      });

      const containerCount = containers.length;
      leafItems.forEach((item, idx) => {
        const derivedParent = this.getParentIdFromElement(item);
        const sectionAncestor = item.closest('[data-section-id]');
        const sectionId = sectionAncestor ? sectionAncestor.getAttribute('data-section-id') : null;
        payload.push({
          id: item.getAttribute("data-id"),
          parent_id: derivedParent === null ? null : String(derivedParent),
          position: containerCount + idx + 1,
          depth: (derivedParent === null) ? 0 : 1,
          section_id: sectionId
        });
      });
    });

    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');
      const resp = await fetch("/admin/menu_bar_items/sort", {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": csrfToken || ""
        },
        body: JSON.stringify({ items: payload })
      });

      let data;
      try {
        data = await resp.json();
      } catch (parseError) {
        console.error("[menu-item-sort] Failed to parse JSON response", parseError);
        data = {};
      }

      if (resp.ok) {
        if (Array.isArray(data)) {
          this.syncPositionsFromServer(data);
        }
        try { this.assignHandleByDepth(); } catch (e) {}

        const message = data.notice || data.message || "Menu items sorted successfully.";
        this.showToast(message, "success");
      } else {
        let message = data.errors || data.error || data.alert || "Failed to sort menu items.";
        if (Array.isArray(message)) {
          message = message.join(", ");
        }
        this.showToast(message, "error");
      }
    } catch (e) {
      console.error("[menu-item-sort] Failed to persist menu item order", e);
      this.showToast("Failed to sort menu items.", "error");
    }

    this.element.dispatchEvent(
      new CustomEvent("menu-item:sorted", {
        detail: { items: payload },
        bubbles: true
      })
    );


    try {
      const post = this.computeState();
      const pre = this._preSortState || {};
      const diffs = [];
      const ids = new Set([...Object.keys(pre), ...Object.keys(post)]);
      ids.forEach(id => {
        const p = pre[id];
        const q = post[id];
        if (!p && q) {
          diffs.push({ id, before: null, after: q });
          return;
        }
        if (p && !q) {
          diffs.push({ id, before: p, after: null });
          return;
        }

        if (JSON.stringify(p) !== JSON.stringify(q)) {
          diffs.push({ id, before: p, after: q });
        }
      });

      try { this.ensureChildIndentation(); } catch (e) {}
      try { this.assignHandleByDepth(); } catch (e) {}

      try {
        const elements = document.querySelectorAll('[data-controller~="menu-item-sort"]');
        elements.forEach(el => {
          try {
            const app = (window.Stimulus && window.Stimulus.application) ? window.Stimulus.application : window.Stimulus;
            const ctrl = app.getControllerForElementAndIdentifier(el, 'menu-item-sort');
            if (ctrl && ctrl !== this) {
              try { ctrl.ensureChildIndentation(); } catch (e) {}
              try { ctrl.assignHandleByDepth(); } catch (e) {}
            }
          } catch (e) { }
        });
      } catch (e) { }
    } catch (e) {

    }
  }
}
