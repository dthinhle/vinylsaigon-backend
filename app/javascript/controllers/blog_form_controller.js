import { Controller } from "@hotwired/stimulus";
import TomSelect from "tom-select"

export default class extends Controller {
  static targets = ["productsSelect"];

  connect() {
    this.initSelectProducts()
  }

  disconnect() {
  }

  initSelectProducts() {
    new TomSelect(this.productsSelectTarget, {
      persist: false,
      valueField: 'id',
      labelField: 'name',
      searchField: 'name',
      preload: 'focus',
      plugins: ['remove_button'],
      load: function(query, callback) {
        fetch(`/admin/products.json?q=${encodeURIComponent(query)}`)
          .then(response => response.json())
          .then(callback);
      },
    });
  }
}
