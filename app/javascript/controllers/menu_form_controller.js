import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  // controller attaches to modal element

  submit(event) {
    event.preventDefault();
    const form = this.element.querySelector('form');
    if (!form) return;

    const url = form.action;
    const method = form.method || 'patch';

    // Client-side validation for link type
    const itemTypeEl = form.querySelector('[name="menu_bar_item[item_type]"]');
    const linkEl = form.querySelector('[name="menu_bar_item[link]"]');
    if (itemTypeEl && itemTypeEl.value === 'link') {
      const linkVal = linkEl ? (linkEl.value || '').trim() : '';
      if (!linkVal) {
        if (linkEl) {
          const next = linkEl.nextElementSibling;
          if (next && next.classList && next.classList.contains('text-red-600')) next.remove();
          const p = document.createElement('p');
          p.className = 'mt-1 text-sm text-red-600';
          p.textContent = 'Link is required for Link type.';
          linkEl.classList.add('border-red-500', 'ring-2', 'ring-red-200');
          linkEl.insertAdjacentElement('afterend', p);
          linkEl.focus();
        }
        this.showToast('Please provide a link for Link type.', 'error');
        return;
      }
    }

    const formData = new FormData(form);

    fetch(url, {
      method: method.toUpperCase(),
      headers: { 'Accept': 'text/vnd.turbo-stream.html' },
      body: formData,
      credentials: 'same-origin'
    })
      .then(response => {
        if (response.ok) {
          response.text().then(html => {
            if (html) window.Turbo.renderStreamMessage(html);
            try {
              this.element.classList.add('hidden');
            } catch (e) {}
            this.showToast('Menu item updated successfully.', 'success');
          });
        } else {
          response.text().then(html => {
            if (response.status === 422) {
              window.Turbo.renderStreamMessage(html);
              // keep modal open
              try { this.element.classList.remove('hidden'); } catch (e) {}
            } else {
              this.showToast('Failed to update menu item.', 'error');
            }
          });
        }
      })
      .catch(error => {
        this.showToast('Network error.', 'error');
        console.error('Error submitting form:', error);
      });
  }

  delete(event) {
    event.preventDefault();
    event.stopPropagation();

    const id = event.currentTarget.dataset.menuItemEditId || event.currentTarget.getAttribute('data-menu-item-edit-id');
    if (!id) {
      this.showToast('Menu item ID missing.', 'error');
      return;
    }

    if (!window.confirm('Are you sure you want to delete this menu item and all its sub-items?')) return;

    const url = `/admin/menu_bar_items/${id}`;
    const token = document.querySelector('meta[name="csrf-token"]')?.content;

    fetch(url, {
      method: 'DELETE',
      headers: {
        'Accept': 'text/vnd.turbo-stream.html',
        'X-CSRF-Token': token || '',
        'X-Requested-With': 'XMLHttpRequest'
      },
      credentials: 'same-origin'
    })
      .then(response => {
        if (response.ok) {
          response.text().then(html => {
            if (html) Turbo.renderStreamMessage(html);
            this.showToast('Menu item deleted.', 'success');
            // Remove entire container (with children) if parent; fallback to single item
            const container = event.currentTarget.closest('[data-menu-container="true"]');
            if (container) {
              try { container.remove(); } catch (e) {}
            } else {
              const itemDiv = event.currentTarget.closest('[data-menu-item="true"]');
              if (itemDiv) try { itemDiv.remove(); } catch (e) {}
            }
          });
        } else {
          response.text().then(() => this.showToast('Failed to delete menu item.', 'error'));
        }
      })
      .catch(() => this.showToast('Network error.', 'error'));
  }

  showToast(message, type = 'success') {
    document.dispatchEvent(new CustomEvent('toast:show', { detail: { message, type } }));
  }
}
