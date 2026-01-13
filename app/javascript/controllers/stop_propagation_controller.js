// app/javascript/controllers/stop_propagation_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  stop(event) {
    event.stopPropagation();
  }
}