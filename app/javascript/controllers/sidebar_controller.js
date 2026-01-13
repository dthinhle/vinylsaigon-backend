import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "icon"];

  connect() {
    this.sidebar = document.getElementById('admin-sidebar')
    this.sidebarContent = document.getElementById('sidebar-content')
    this.mainContent = document.getElementById('main-content')
    this.collapsed = this.sidebar?.classList.contains('collapsed') || false
  }

  toggleSidebar(event) {
    this.setSidebarState(!this.collapsed)
  }

  toggleSidebarKey(event) {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault()
      this.setSidebarState(!this.collapsed)
    }
  }

  setSidebarState(isCollapsed) {
    this.collapsed = isCollapsed
    this.setCookie('sidebar_collapsed', String(this.collapsed), 365)
    if (this.sidebar) {
      this.sidebar.setAttribute('aria-expanded', String(!this.collapsed))
      this.sidebar.classList.toggle('collapsed', this.collapsed)
      this.sidebar.classList.toggle('w-16', this.collapsed)
      this.sidebar.classList.toggle('w-64', !this.collapsed)
      this.sidebar.querySelectorAll('.collapse-hide').forEach(el => {
        el.classList.toggle('opacity-0', this.collapsed)
      })
      this.sidebar.querySelectorAll('[role="sidebar-group"]').forEach(el => {
        el.dataset.collapse = this.collapsed
      })
    }
    if (this.hasToggleTarget) this.toggleTarget.setAttribute('aria-pressed', String(this.collapsed))
    if (this.mainContent) {
      this.mainContent.classList.toggle('md:ml-16', this.collapsed)
      this.mainContent.classList.toggle('md:ml-64', !this.collapsed)
      this.mainContent.classList.toggle('ml-16', this.collapsed)
      this.mainContent.classList.toggle('ml-64', !this.collapsed)
    }
    if (this.hasIconTarget) this.iconTarget.textContent = this.collapsed ? 'chevron_right' : 'chevron_left'
  }

  setCookie(name, value, days) {
    const expires = new Date(Date.now() + days * 864e5).toUTCString()
    document.cookie = `${name}=${encodeURIComponent(value)}; expires=${expires}; path=/; SameSite=Lax`
  }
}
