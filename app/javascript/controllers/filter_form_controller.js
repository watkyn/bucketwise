import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "nubbin"]

  display(event) {
    event.preventDefault()
    this.formTarget.classList.remove("hidden")
  }

  hide(event) {
    event.preventDefault()
    this.formTarget.classList.add("hidden")
  }
}
