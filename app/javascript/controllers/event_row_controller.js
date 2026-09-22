import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // NOTE: nubbin/deleteForm/data targets are intentionally NOT declared:
  // every action below scopes via getElementById, so per-row instances work
  // without in-row targets. Don't add data-*-target lookups without also
  // adding the targets to _row.html.haml.

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
    }).then(async response => {
      const html = await response.text()
      if (!response.ok) throw new Error(html || `Delete failed (${response.status})`)
      if (html) Turbo.renderStreamMessage(html)
    }).catch(err => {
      alert(err.message || "An error occurred")
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
    }).then(async response => {
      const html = await response.text()
      if (!response.ok) throw new Error(`Request failed (${response.status})`)
      if (html) Turbo.renderStreamMessage(html)
      const row = document.getElementById(`event_${id}`)
      if (row) {
        row.classList.remove("zooming")
        row.classList.add("zoomed")
      }
    }).catch(() => {
      const row = document.getElementById(`event_${id}`)
      if (row) row.classList.remove("zooming")
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
