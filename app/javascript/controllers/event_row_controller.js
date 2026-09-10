import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["nubbin", "deleteForm", "data"]

  showNubbin(event) {
    const id = this.element.dataset.eventId
    const nubbin = document.getElementById(`nubbin_event_${id}`)
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

  hideNubbin(event) {
    const id = this.element.dataset.eventId
    const nubbin = document.getElementById(`nubbin_event_${id}`)
    if (nubbin) {
      nubbin.classList.add("hidden")
    }
  }

  edit(event) {
    event.preventDefault()
    const url = event.currentTarget.dataset.url
    const returnTo = window.location.pathname
    window.location = url + "?return_to=" + encodeURIComponent(returnTo)
  }

  delete(event) {
    event.preventDefault()
    if (!confirm("Do you wish to delete this transaction?")) return

    const url = event.currentTarget.dataset.url
    const token = event.currentTarget.dataset.token
    const source = window.BucketWise?.source || ""

    const params = new URLSearchParams()
    params.append("authenticity_token", token)
    params.append("from", source)

    fetch(url, {
      method: "DELETE",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": token,
        "Accept": "text/vnd.turbo-stream.html"
      },
      body: params.toString()
    })
  }

  expand(event) {
    event.preventDefault()
    const id = this.element.dataset.eventId
    const existing = document.getElementById(`zoomed_event_${id}`)
    if (existing) return

    const row = document.getElementById(`event_${id}`)
    if (row) row.classList.add("zooming")

    const url = event.currentTarget.dataset.url
    fetch(url, {
      headers: { "Accept": "text/vnd.turbo-stream.html" }
    })
  }

  collapse(event) {
    event.preventDefault()
    const id = this.element.dataset.eventId
    const row = document.getElementById(`event_${id}`)
    if (row) {
      row.classList.remove("zoomed")
    }
    const zoomed = document.getElementById(`zoomed_event_${id}`)
    if (zoomed) zoomed.remove()
  }
}
