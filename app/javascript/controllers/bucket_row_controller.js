import { Controller } from "@hotwired/stimulus"
import { Money } from "money"

export default class extends Controller {
  static targets = ["nubbin", "deleteForm", "data"]

  connect() {
    this.newEventUrl = this.element.dataset.bucketsNewEventUrlValue || null
  }

  showNubbin() {
    const id = this.element.dataset.bucketId
    const nubbin = document.getElementById(`nubbin_bucket_${id}`)
    if (nubbin) {
      nubbin.classList.remove("hidden")
      nubbin.classList.add("absolute")
      const row = nubbin.closest("tr")
      if (row) {
        const rect = row.getBoundingClientRect()
        nubbin.style.left = `${rect.left - nubbin.offsetWidth}px`
      }
    }
  }

  hideNubbin() {
    const id = this.element.dataset.bucketId
    const nubbin = document.getElementById(`nubbin_bucket_${id}`)
    if (nubbin) {
      nubbin.classList.add("hidden")
    }
  }

  transferTo(event) {
    event.preventDefault()
    const accountId = event.currentTarget.dataset.accountId
    const bucketId = event.currentTarget.dataset.bucketId

    if (this.newEventUrl) {
      window.location = this.newEventUrl + "?role=reallocation&to=" + bucketId
    } else {
      this.revealReallocation("to", accountId, bucketId)
    }
  }

  transferFrom(event) {
    event.preventDefault()
    const accountId = event.currentTarget.dataset.accountId
    const bucketId = event.currentTarget.dataset.bucketId

    if (this.newEventUrl) {
      window.location = this.newEventUrl + "?role=reallocation&from=" + bucketId
    } else {
      this.revealReallocation("from", accountId, bucketId)
    }
  }

  // Pages without a dedicated new-event page (e.g. the subscription
  // dashboard) reveal the inline reallocation form instead of navigating.
  revealReallocation(direction, accountId, bucketId) {
    const form = document.querySelector('[data-controller~="events-form"]')
    const controller = form && this.application.getControllerForElementAndIdentifier(form, "events-form")
    if (controller) controller.revealReallocation(direction, accountId, bucketId)
  }

  rename(event) {
    event.preventDefault()
    const url = event.currentTarget.dataset.url
    const currentName = event.currentTarget.dataset.name
    const token = event.currentTarget.dataset.token

    const newName = prompt("Enter the name for this bucket:", currentName)
    if (newName && newName !== currentName) {
      const view = document.querySelectorAll("tr.bucket").length > 0 ? "index" : "perma"
      const params = new URLSearchParams()
      params.append("bucket[name]", newName)
      params.append("authenticity_token", token)
      params.append("view", view)

      fetch(url, {
        method: "PUT",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": token,
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: params.toString()
      })
    }
  }

  deleteBucket(event) {
    event.preventDefault()
    // These targets live on the page-level controller scope (e.g. buckets/show
    // wraps #delete_form and #data). Index rows reuse this controller for
    // hover/rename only, so degrade gracefully if the scope has no targets.
    if (this.hasDataTarget) this.dataTarget.classList.add("hidden")
    if (this.hasDeleteFormTarget) this.deleteFormTarget.classList.remove("hidden")
  }

  confirmDelete(event) {
    if (!confirm("Are you sure you want to delete this bucket?")) {
      event.preventDefault()
    }
  }

  cancelDelete(event) {
    if (event) event.preventDefault()
    if (this.hasDeleteFormTarget) this.deleteFormTarget.classList.add("hidden")
    if (this.hasDataTarget) this.dataTarget.classList.remove("hidden")
  }
}
