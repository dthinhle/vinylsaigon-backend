// baka-backend/app/javascript/controllers/categories_index_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["q", "isRoot", "parentId", "sort", "direction", "modal", "modalImage"];

  connect() {}

  // Submit filter form on Enter or change
  submitOnChange(event) {
    event.target.form.requestSubmit();
  }

  // Confirm delete action
  confirmDelete(event) {
    if (!window.confirm("Are you sure you want to delete this category?")) {
      event.preventDefault();
      event.stopPropagation();
    }
  }

  openImagePreview(event) {
    event.preventDefault();
    const imageUrl = event.currentTarget.getAttribute("data-image-url");
    if (this.hasModalTarget && this.hasModalImageTarget) {
      this.modalImageTarget.src = imageUrl;
      this.modalTarget.classList.remove("hidden");
      this.modalTarget.classList.add("flex");
      this.modalTarget.focus();
    }
  }

  closeModal(event) {
    if (this.hasModalTarget) {
      this.modalTarget.classList.add("hidden");
      this.modalTarget.classList.remove("flex");
      if (this.hasModalImageTarget) {
        this.modalImageTarget.src = "";
      }
    }
  }

  closeOnEsc(event) {
    if (event.key === "Escape" && this.hasModalTarget && !this.modalTarget.classList.contains("hidden")) {
      this.closeModal();
    }
  }
}