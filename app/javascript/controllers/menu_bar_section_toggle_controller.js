// Verify SortableJS asset pipeline integration
import Sortable from "sortablejs";
// Stimulus controller for collapsible MenuBar::Section
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "arrow"]

  connect() {
    this.expanded = false
    this.update()
  }

  toggle() {
    this.expanded = !this.expanded
    this.update()
  }

  update() {
    this.contentTarget.classList.toggle("hidden", !this.expanded)
    this.arrowTarget.classList.toggle("rotate-90", this.expanded)
  }
}