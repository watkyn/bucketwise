import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "list"]
  static values = { items: Array, tokens: String }

  connect() {
    this.currentIndex = -1
    this.filteredItems = []
  }

  search(event) {
    const query = this.inputTarget.value.toLowerCase()

    if (this.tokensValue) {
      const parts = query.split(this.tokensValue)
      const lastPart = parts[parts.length - 1].trim()
      if (lastPart === "") {
        this.hide()
        return
      }
      this.filterAndShow(lastPart)
    } else {
      if (query === "") {
        this.hide()
        return
      }
      this.filterAndShow(query)
    }
  }

  filterAndShow(query) {
    this.filteredItems = this.itemsValue.filter(item =>
      item.toLowerCase().includes(query)
    )

    if (this.filteredItems.length === 0) {
      this.hide()
      return
    }

    this.listTarget.innerHTML = ""
    this.filteredItems.forEach((item, index) => {
      const li = document.createElement("li")
      li.textContent = item
      li.classList.add("cursor-pointer", "px-2", "py-1", "hover:bg-yellow-100")
      li.dataset.index = index
      li.addEventListener("click", () => this.select(item))
      this.listTarget.appendChild(li)
    })

    this.listTarget.classList.remove("hidden")
    this.currentIndex = -1
  }

  select(item) {
    if (this.tokensValue) {
      const parts = this.inputTarget.value.split(this.tokensValue)
      parts[parts.length - 1] = " " + item
      this.inputTarget.value = parts.join(this.tokensValue)
    } else {
      this.inputTarget.value = item
    }
    this.hide()
    this.inputTarget.focus()
  }

  hide() {
    this.listTarget.classList.add("hidden")
    this.listTarget.innerHTML = ""
    this.filteredItems = []
    this.currentIndex = -1
  }

  navigate(event) {
    if (this.listTarget.classList.contains("hidden")) return

    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.currentIndex = Math.min(this.currentIndex + 1, this.filteredItems.length - 1)
      this.highlight()
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.currentIndex = Math.max(this.currentIndex - 1, 0)
      this.highlight()
    } else if (event.key === "Enter" && this.currentIndex >= 0) {
      event.preventDefault()
      this.select(this.filteredItems[this.currentIndex])
    } else if (event.key === "Escape") {
      this.hide()
    }
  }

  highlight() {
    this.listTarget.querySelectorAll("li").forEach((li, i) => {
      if (i === this.currentIndex) {
        li.classList.add("bg-yellow-100")
      } else {
        li.classList.remove("bg-yellow-100")
      }
    })
  }

  outsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.hide()
    }
  }
}
