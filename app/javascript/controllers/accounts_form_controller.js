import { Controller } from "@hotwired/stimulus"
import { Money } from "money"

export default class extends Controller {
  static targets = ["form", "blankslate", "data", "links", "nameField", "roleField", "limitDiv", "creditLimitField", "startingBalance"]

  connect() {
    this.origin = this.element.dataset.accountsFormOriginValue || null
  }

  reveal(event) {
    if (event) event.preventDefault()
    if (this.hasBlankslateTarget) {
      this.blankslateTarget.classList.add("hidden")
    } else if (this.hasDataTarget) {
      this.dataTarget.classList.add("hidden")
      if (this.hasLinksTarget) this.linksTarget.classList.add("hidden")
    }

    const form = this.hasFormTarget ? this.formTarget : this.element
    form.classList.remove("hidden")
    this.nameFieldTarget.focus()
  }

  hide(event) {
    if (event) event.preventDefault()
    if (this.origin) {
      window.location = this.origin
      return
    }

    this.reset()
    const form = this.hasFormTarget ? this.formTarget : this.element
    form.classList.add("hidden")

    if (this.hasBlankslateTarget) {
      this.blankslateTarget.classList.remove("hidden")
    } else if (this.hasDataTarget) {
      this.dataTarget.classList.remove("hidden")
      if (this.hasLinksTarget) this.linksTarget.classList.remove("hidden")
    }
  }

  reset() {
    const form = this.hasFormTarget ? this.formTarget : this.element
    const inner = form.matches("form") ? form : form.querySelector("form")
    if (inner) inner.reset()
  }

  validate(event) {
    const name = this.nameFieldTarget.value.trim()
    if (!name) {
      this.nameFieldTarget.focus()
      alert("Please provide a name for the account.")
      event.preventDefault()
      return
    }

    if (this.roleFieldTarget.value === "credit-card") {
      const limit = this.creditLimitFieldTarget.value.trim()
      if (!limit) {
        this.nameFieldTarget.focus()
        alert("Please provide a limit for the account.")
        event.preventDefault()
        return
      }
    }

    if (this.hasStartingBalanceTarget) {
      const balance = Money.parse("current_balance", true)
      this.startingBalanceTarget.value = balance
    }

    const limitField = this.element.querySelector("#account_limit")
    if (limitField) {
      limitField.value = Money.parse("account_limit", true)
    }
  }

  toggleCreditLimit() {
    if (this.roleFieldTarget.value === "credit-card") {
      this.limitDivTarget.classList.remove("hidden")
    } else {
      this.limitDivTarget.classList.add("hidden")
    }
  }

  rename(event) {
    event.preventDefault()
    const url = event.currentTarget.dataset.url
    const currentName = event.currentTarget.dataset.name
    const token = event.currentTarget.dataset.token

    const newName = prompt("Enter the name for this account:", currentName)
    if (newName && newName !== currentName) {
      const params = new URLSearchParams()
      params.append("account[name]", newName)
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

  adjustLimit(event) {
    event.preventDefault()
    const url = event.currentTarget.dataset.url
    const currentLimit = parseInt(event.currentTarget.dataset.limit)
    const token = event.currentTarget.dataset.token

    let newLimit = prompt("Enter the new limit for this account:", Money.formatValue(currentLimit))
    if (newLimit === null) return

    newLimit = Money.parseValue(newLimit)
    while (newLimit === "" || isNaN(newLimit)) {
      newLimit = prompt("Cannot have a blank limit. Please re-enter it:", Money.formatValue(currentLimit))
      if (newLimit === null) return
      newLimit = Money.parseValue(newLimit)
    }

    if (newLimit !== currentLimit) {
      const params = new URLSearchParams()
      params.append("account[limit]", newLimit)
      params.append("authenticity_token", token)

      fetch(url, {
        method: "PUT",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": token,
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: params.toString()
      }).then(() => window.location.reload())
    }
  }
}
