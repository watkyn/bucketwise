import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { location: String }

  connect() {
    window.BucketWise = window.BucketWise || {}
    window.BucketWise.source = this.locationValue
  }
}
