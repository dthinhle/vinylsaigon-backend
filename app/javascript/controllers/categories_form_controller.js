// baka-backend/app/javascript/controllers/categories_form_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "fileInput",
    "previewImage",
    "isRoot",
    "parentSelect"
  ];

  connect() {
    this.toggleParentSelect();
    if (this.fileInputTarget && this.fileInputTarget.files.length > 0) {
      this.showPreview();
    }
  }

  fileChanged() {
    this.showPreview();
  }

  showPreview() {
    const input = this.fileInputTarget;
    const preview = this.previewImageTarget;
    if (input && input.files && input.files[0]) {
      const reader = new FileReader();
      reader.onload = e => {
        preview.src = e.target.result;
        preview.classList.remove("hidden");
      };
      reader.readAsDataURL(input.files[0]);
    } else if (preview) {
      preview.src = "";
      preview.classList.add("hidden");
    }
  }

  toggleParentSelect() {
    if (this.isRootTarget && this.parentSelectTarget) {
      this.parentSelectTarget.disabled = this.isRootTarget.checked;
    }
  }
}