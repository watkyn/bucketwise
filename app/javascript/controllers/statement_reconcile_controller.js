import { Controller } from "@hotwired/stimulus"
import { Money } from "money"

export default class extends Controller {
  static targets = ["balanced", "actions", "endingBalance"]

  clickItem(event) {
    const id = event.currentTarget.dataset.itemId
    const checkbox = document.getElementById(`check_account_item_${id}`)
    if (checkbox) checkbox.click()
  }

  toggleCleared(event) {
    const id = event.currentTarget.dataset.itemId
    const checkbox = document.getElementById(`check_account_item_${id}`)
    const amountSpan = document.getElementById(`amount_account_item_${id}`)
    const row = document.getElementById(`account_item_${id}`)

    if (!checkbox || !amountSpan || !row) return

    const amount = parseInt(amountSpan.innerHTML)
    const fieldset = row.closest("fieldset")
    const subtotalField = fieldset.querySelector(".subtotal_dollars")
    const subtotal = Money.parseValue(subtotalField.innerHTML, true)

    if (checkbox.checked) {
      row.classList.add("cleared")
      subtotalField.innerHTML = "$" + Money.formatValue(subtotal + amount)
    } else {
      row.classList.remove("cleared")
      subtotalField.innerHTML = "$" + Money.formatValue(subtotal - amount)
    }

    this.updateBalances()
  }

  updateEndingBalance() {
    if (this.hasEndingBalanceTarget) {
      this.endingBalanceTarget.value = Money.format(this.endingBalanceTarget)
    }
    this.updateBalances()
  }

  updateBalances() {
    const endingEl = document.getElementById("statement_ending_balance")
    if (endingEl) {
      endingEl.value = Money.format(endingEl)
    }

    const remaining = this.computeRemaining()

    for (const section of ["deposits", "checks", "expenses"]) {
      const sectionEl = document.getElementById(section)
      if (sectionEl) {
        const span = sectionEl.querySelector(".remaining_dollars")
        if (span) {
          if (remaining === 0) {
            span.classList.add("balanced")
          } else {
            span.classList.remove("balanced")
          }
          span.innerHTML = "$" + Money.formatValue(remaining)
        }
      }
    }

    if (this.hasBalancedTarget) {
      if (remaining === 0) {
        this.balancedTarget.classList.remove("hidden")
        this.actionsTarget.classList.add("hidden")
      } else {
        this.balancedTarget.classList.add("hidden")
        this.actionsTarget.classList.remove("hidden")
      }
    }
  }

  computeRemaining() {
    const startingBalanceEl = document.getElementById("starting_balance")
    const cachedBalance = startingBalanceEl ? Money.parseValue(startingBalanceEl.innerHTML, true) : 0

    let settled = 0
    document.querySelectorAll(".subtotal_dollars").forEach(span => {
      settled += Money.parseValue(span.innerHTML, true)
    })

    const endingEl = document.getElementById("statement_ending_balance")
    const endingBalance = endingEl ? Money.parse(endingEl, true) : 0

    return cachedBalance + settled - endingBalance
  }
}
