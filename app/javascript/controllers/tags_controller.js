import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["deleteForm", "data", "deleteOption", "mergeOption", "receiverSelect"]

  rename(event) {
    event.preventDefault()
    const url = event.currentTarget.dataset.url
    const currentName = event.currentTarget.dataset.name
    const token = event.currentTarget.dataset.token

    const newName = prompt("Enter the name for this tag:", currentName)
    if (newName && newName !== currentName) {
      const params = new URLSearchParams()
      params.append("tag[name]", newName)
      params.append("authenticity_token", token)

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

  deleteTag(event) {
    event.preventDefault()
    const fieldset = this.deleteFormTarget.querySelector("fieldset")
    if (fieldset) {
      this.deleteFormTarget.classList.remove("hidden")
      this.dataTarget.classList.add("hidden")
    } else if (confirm("Are you sure you want to delete this tag?")) {
      this.deleteFormTarget.querySelector("form").submit()
    }
  }

  confirmDelete(event) {
    if (this.mergeOptionTarget.querySelector("input").checked) {
      if (this.receiverSelectTarget.selectedIndex <= 0) {
        alert("If you want to merge tags, you must select a tag to merge with.")
        this.receiverSelectTarget.focus()
        event.preventDefault()
        return
      }
    } else {
      this.receiverSelectTarget.selectedIndex = 0
    }

    if (!confirm("Are you sure you want to delete this tag?")) {
      event.preventDefault()
    }
  }

  cancelDelete() {
    this.deleteFormTarget.querySelector("form").reset()
    this.selectDelete()
    this.deleteFormTarget.classList.add("hidden")
    this.dataTarget.classList.remove("hidden")
  }

  selectDelete() {
    this.receiverSelectTarget.selectedIndex = 0
    this.deleteOptionTarget.classList.add("selected")
    this.mergeOptionTarget.classList.remove("selected")
  }

  selectMerge() {
    this.mergeOptionTarget.classList.add("selected")
    this.deleteOptionTarget.classList.remove("selected")
  }
}
