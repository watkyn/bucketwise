import { Controller } from "@hotwired/stimulus"
import { Money } from "javascript/money"

export default class extends Controller {
  static targets = [
    "form", "newEvent", "successNotice",
    "generalInfo", "paymentSource", "creditOptions", "deposit",
    "transferFrom", "transferTo", "reallocateFrom", "reallocateTo",
    "tags", "tagsCollapsed", "tagItems", "tagItemsCollapsed", "taggedItems",
    "memo", "memoLink", "recallEvent",
    "expenseTotal", "actorName", "checkNumber",
    "actorNameSelect", "expenseLink", "depositLink", "transferLink",
    "links"
  ]

  static values = {
    accounts: Object,
    tags: Array,
    actors: Array,
    returnTo: String,
    defaultActor: String,
    defaultDate: String,
    source: String
  }

  connect() {
    this.nextID = 0
    this.recalledEvents = null
    this.currentEvent = -1
  }

  revealExpense() {
    this.highlightLink("expense_link")
    this.revealBasicForm()
    this.showLabels("expense_label")
    this.paymentSourceTarget.classList.remove("hidden")
  }

  revealDeposit() {
    this.highlightLink("deposit_link")
    this.revealBasicForm()
    this.showLabels("deposit_label")
    this.depositTarget.classList.remove("hidden")
  }

  revealTransfer() {
    this.highlightLink("transfer_link")
    this.revealBasicForm()
    this.showLabels("transfer_label")
    this.transferFromTarget.classList.remove("hidden")
    this.transferToTarget.classList.remove("hidden")
  }

  revealBasicForm() {
    this.newEventTarget.classList.remove("hidden")
    this.successNoticeTarget.classList.add("hidden")
    this.hideAllLabels()
    this.generalInfoTarget.classList.remove("hidden")
    this.hideAllSections()
  }

  hideAllSections() {
    const sections = [
      this.paymentSourceTarget, this.creditOptionsTarget,
      this.depositTarget, this.transferFromTarget, this.transferToTarget,
      this.reallocateFromTarget, this.reallocateToTarget
    ]
    sections.forEach(s => { if (s) s.classList.add("hidden") })
  }

  showLabels(className) {
    this.element.querySelectorAll(`.${className}`).forEach(el => el.classList.remove("hidden"))
  }

  hideAllLabels() {
    this.element.querySelectorAll(".expense_label, .deposit_label, .transfer_label").forEach(el => el.classList.add("hidden"))
  }

  highlightLink(id) {
    if (this.hasLinksTarget) {
      this.linksTarget.querySelectorAll("a").forEach(link => {
        if (link.id === id) {
          link.classList.add("bg-bucketwise-green", "text-bucketwise-green-dark", "border", "border-bucketwise-green-dark")
        } else {
          link.classList.remove("bg-bucketwise-green", "text-bucketwise-green-dark", "border", "border-bucketwise-green-dark")
        }
      })
    }
  }

  cancel() {
    if (this.returnToValue) {
      window.location.href = this.returnToValue
    } else {
      this.highlightLink("")
      this.reset()
      this.newEventTarget.classList.add("hidden")
    }
  }

  reset() {
    this.formTarget.reset()
    this.hideAllSections()
    this.memoTarget.classList.add("hidden")
    this.memoLinkTarget.classList.remove("hidden")
    this.tagItemsTarget.classList.add("hidden")
    this.tagItemsCollapsedTarget.classList.remove("hidden")
    this.taggedItemsTarget.innerHTML = ""
    this.tagsTarget.classList.add("hidden")
    this.tagsCollapsedTarget.classList.remove("hidden")
    this.recallEventTarget.classList.add("hidden")
  }

  revealMemo() {
    this.memoLinkTarget.classList.add("hidden")
    this.memoTarget.classList.remove("hidden")
    this.memoTarget.querySelector("textarea").focus()
  }

  revealTags() {
    this.tagsCollapsedTarget.classList.add("hidden")
    this.tagsTarget.classList.remove("hidden")
    this.tagsTarget.querySelector("input").focus()
  }

  revealPartialTags() {
    this.addTaggedItem()
    this.addTaggedItem()
    this.tagItemsCollapsedTarget.classList.add("hidden")
    this.tagItemsTarget.classList.remove("hidden")
    this.tagItemsTarget.querySelector("input").focus()
  }

  handleAccountChange(event) {
    const select = event.currentTarget
    const section = select.dataset.section
    const sectionEl = document.getElementById(section)
    if (!sectionEl) return

    const multipleBuckets = document.getElementById(`${section}.multiple_buckets`)
    const lineItems = document.getElementById(`${section}.line_items`)
    const singleBucket = document.getElementById(`${section}.single_bucket`)

    if (multipleBuckets) multipleBuckets.classList.add("hidden")
    if (lineItems) lineItems.innerHTML = ""
    if (singleBucket) singleBucket.classList.remove("hidden")

    this.updateBucketsFor(section, true)

    const checkOptions = document.getElementById(`${section}.check_options`)
    const repaymentOptions = document.getElementById(`${section}.repayment_options`)
    const creditOptions = document.getElementById("credit_options")

    if (checkOptions) checkOptions.classList.add("hidden")
    if (repaymentOptions) repaymentOptions.classList.add("hidden")
    if (creditOptions && section === "payment_source") creditOptions.classList.add("hidden")

    if (select.value !== "") {
      const acctId = parseInt(select.value)
      const account = this.accountsValue[acctId]
      if (!account) return

      if (account.role === "credit-card" && section === "payment_source" && repaymentOptions) {
        repaymentOptions.classList.remove("hidden")
      }
      if (account.role === "checking" && checkOptions) {
        checkOptions.classList.remove("hidden")
      }
    }
  }

  handleBucketChange(event) {
    const select = event.currentTarget
    const section = select.dataset.section
    const selected = select.value

    if (selected === "+") {
      this.addLineItemTo(section, true)
      this.addLineItemTo(section, true)
      const multipleBuckets = document.getElementById(`${section}.multiple_buckets`)
      const singleBucket = document.getElementById(`${section}.single_bucket`)
      if (multipleBuckets) multipleBuckets.classList.remove("hidden")
      if (singleBucket) singleBucket.classList.add("hidden")
      this.updateBucketsFor(section)
    } else if (selected === "++") {
      const acctId = document.getElementById(`account_for_${section}`)?.value
      const name = prompt("Name your new bucket:")
      if (name && acctId) {
        const value = "n:" + name
        this.accountsValue[acctId].buckets.push({ id: value, name: name })
        this.accountsValue[acctId].buckets.sort((a, b) => a.name.localeCompare(b.name))
        this.updateBucketsFor(section)
        this.selectBucket(select, value)
      } else {
        select.selectedIndex = 0
      }
    }
  }

  showRepaymentOptions(event) {
    const section = event.currentTarget.dataset.section
    const repaymentOptions = document.getElementById(`${section}.repayment_options`)
    const creditOptions = document.getElementById("credit_options")
    if (repaymentOptions) repaymentOptions.classList.add("hidden")
    if (creditOptions) creditOptions.classList.remove("hidden")
  }

  updateBucketsFor(section, reset) {
    const skipAside = section === "credit_options"
    const acctField = document.getElementById(`account_for_${section}`)
    if (!acctField) return

    const disabled = acctField.tagName === "SELECT" && acctField.value === ""
    const acctId = disabled ? null : acctField.value

    const bucketSelects = this.element.querySelectorAll(`#${section} select.bucket_for_${section}`)
    bucketSelects.forEach(select => {
      this.populateBucket(select, acctId, { reset, disabled, skipAside })
    })
  }

  populateBucket(select, acctId, options = {}) {
    let selected
    if (select.selectedIndex >= 0) {
      selected = select.options[select.selectedIndex]?.value
    }

    while (select.options.length > 0) select.options[0] = null

    if (options.disabled) {
      select.disabled = true
      select.options[0] = new Option("-- Select an account --", "")
    } else {
      select.disabled = false
      let i = 0
      const buckets = this.accountsValue[acctId]?.buckets || []
      buckets.forEach(bucket => {
        if (bucket.role !== "aside" || !options.skipAside) {
          select.options[i++] = new Option(bucket.name, bucket.id)
        }
      })

      if (select.classList.contains("splittable")) {
        select.options[i++] = new Option("-- More than one --", "+")
      }
      select.options[i++] = new Option("-- Add a new bucket --", "++")

      if (!options.reset && selected) {
        this.selectBucket(select, selected)
      }
    }
  }

  selectBucket(select, value) {
    for (let i = 0; i < select.options.length; i++) {
      if (select.options[i].value == value) {
        select.selectedIndex = i
        break
      }
    }
  }

  addLineItem(event) {
    event.preventDefault()
    const section = event.currentTarget.dataset.section
    this.addLineItemTo(section, true)
  }

  addLineItemTo(section, populate) {
    const ol = document.getElementById(`${section}.line_items`)
    if (!ol) return

    const template = document.getElementById(`template.${section}`)
    if (!template) return

    const li = document.createElement("li")
    li.innerHTML = template.innerHTML
    ol.appendChild(li)

    if (populate) {
      const acctSelect = document.getElementById(`account_for_${section}`)
      const acctId = acctSelect?.value
      const bucketSelect = li.querySelector("select")
      if (bucketSelect && acctId) {
        this.populateBucket(bucketSelect, acctId, { skipAside: section === "credit_options" })
      }
    }

    const input = li.querySelector("input")
    if (input) input.focus()
  }

  removeLineItem(event) {
    event.preventDefault()
    const li = event.currentTarget.closest("li")
    if (li) li.remove()
    this.updateUnassigned()
  }

  addTaggedItem() {
    const ol = this.taggedItemsTarget
    const template = document.getElementById("template.tags")
    if (!ol || !template) return

    const li = document.createElement("li")
    const id = `tagged_item_i${this.nextID++}`
    li.innerHTML = template.innerHTML.replace(/\{ID\}/g, id)
    ol.appendChild(li)

    const input = li.querySelector("input")
    if (input) input.focus()
  }

  removeTaggedItem(event) {
    event.preventDefault()
    const li = event.currentTarget.closest("li")
    if (li) li.remove()
  }

  updateUnassigned() {
    if (this.hasSuccessNoticeTarget) this.successNoticeTarget.classList.add("hidden")
    for (const section of ["payment_source", "credit_options", "deposit", "transfer_from", "transfer_to"]) {
      this.updateUnassignedFor(section)
    }
  }

  updateUnassignedFor(section) {
    const sectionEl = document.getElementById(section)
    if (!sectionEl) return

    const total = Money.parse("expense_total")
    let lineTotal = 0
    const lineItems = document.getElementById(`${section}.line_items`)
    if (lineItems) {
      lineItems.querySelectorAll("input[type=text]").forEach(field => {
        lineTotal += Money.parse(field)
      })
    }

    const unassigned = total - lineTotal
    const unassignedEl = document.getElementById(`${section}.unassigned`)
    if (!unassignedEl) return

    if (unassigned > 0) {
      unassignedEl.innerHTML = `<strong>$${Money.dollars(unassigned)}</strong> of $${Money.dollars(total)} remains unallocated.`
    } else if (unassigned < 0) {
      unassignedEl.innerHTML = `You've overallocated <strong>$${Money.dollars(unassigned)}</strong>.`
    } else {
      unassignedEl.innerHTML = ""
    }
  }

  updateAmount() {
    this.updateUnassigned()
  }

  checkActorName() {
    if (this.actorNameTarget.value.trim()) {
      this.recallEventTarget.classList.remove("hidden")
    } else {
      this.recallEventTarget.classList.add("hidden")
    }
    this.recalledEvents = null
  }

  recall(event) {
    event.preventDefault()
    if (!this.recalledEvents) {
      this.loadRecalledEvents(event.currentTarget.dataset.url)
      return
    }

    if (this.recalledEvents.length === 0) {
      alert("No transactions matched the criteria you specified.")
      return
    }

    this.currentEvent = (this.currentEvent + 1) % this.recalledEvents.length
    const evt = this.recalledEvents[this.currentEvent].event
    this.rehydrate(evt)
  }

  loadRecalledEvents(url) {
    const params = `page=0&size=10&actor=${encodeURIComponent(this.actorNameTarget.value)}`
    fetch(`${url}?${params}`, {
      headers: { "Accept": "application/json" }
    })
      .then(r => r.json())
      .then(data => {
        this.recalledEvents = data
        this.currentEvent = -1
        this.recallEvent()
      })
  }

  rehydrate(event) {
    const savedDate = document.getElementById("event_occurred_on")?.value
    const savedActor = document.getElementById("event_actor_name")?.value

    this.reset()

    if (savedDate) document.getElementById("event_occurred_on").value = savedDate
    if (savedActor) document.getElementById("event_actor_name").value = savedActor
    if (this.hasExpenseTotalTarget) this.expenseTotalTarget.value = Money.formatValue(event.value)

    const memoField = document.getElementById("event_memo")
    if (memoField) {
      memoField.value = event.memo || ""
      if (memoField.value) this.revealMemo()
    }

    this.recallEventTarget.classList.remove("hidden")

    switch (event.role) {
      case "expense":
        this.revealExpense()
        this.rehydrateSection("payment_source", event)
        this.rehydrateSection("credit_options", event)
        break
      case "deposit":
        this.revealDeposit()
        this.rehydrateSection("deposit", event)
        break
      case "transfer":
        this.revealTransfer()
        this.rehydrateSection("transfer_from", event)
        this.rehydrateSection("transfer_to", event)
        break
      default:
        alert(`Can't rehydrate '${event.role}' events`)
        return
    }

    this.rehydrateTagsForEvent(event)
  }

  rehydrateSection(section, event) {
    const items = event.line_items.filter(item => item.role === section)
    if (items.length === 0) return

    const sectionEl = document.getElementById(section)
    if (sectionEl) sectionEl.classList.remove("hidden")

    const account = this.accountsValue[items[0].account_id]
    const acctSelect = document.getElementById(`account_for_${section}`)
    if (acctSelect && account) {
      acctSelect.value = account.id
      if (account.role === "checking") {
        const checkOptions = document.getElementById(`${section}.check_options`)
        if (checkOptions) checkOptions.classList.remove("hidden")
        const checkNumber = document.getElementById("event_check_number")
        if (checkNumber) checkNumber.value = event.check_number || ""
      }
    }

    this.updateBucketsFor(section)

    if (items.length === 1) {
      const singleBucket = document.getElementById(`${section}.single_bucket`)
      const select = singleBucket?.querySelector("select")
      if (select) this.selectBucket(select, items[0].bucket_id)
    } else {
      const multipleBuckets = document.getElementById(`${section}.multiple_buckets`)
      const singleBucket = document.getElementById(`${section}.single_bucket`)
      if (multipleBuckets) multipleBuckets.classList.remove("hidden")
      if (singleBucket) singleBucket.classList.add("hidden")

      items.forEach(item => {
        this.addLineItemTo(section, item)
      })
    }
  }

  rehydrateTagsForEvent(event) {
    const wholeTags = []
    const partialTags = []

    event.tagged_items.forEach(item => {
      if (item.amount < event.value) {
        partialTags.push(item)
      } else {
        wholeTags.push(item)
      }
    })

    if (wholeTags.length > 0 || partialTags.length > 0) {
      this.revealTags()
      if (wholeTags.length > 0) {
        const tags = wholeTags.map(item => item.name).join(", ")
        const input = this.tagsTarget.querySelector("input")
        if (input) input.value = tags
      }
      if (partialTags.length > 0) {
        this.tagItemsCollapsedTarget.classList.add("hidden")
        this.tagItemsTarget.classList.remove("hidden")
        partialTags.forEach(item => this.addTaggedItem())
      }
    }
  }

  submit(event) {
    event.preventDefault()

    try {
      const data = this.serialize()
      const action = this.formTarget.action

      fetch(action, {
        method: "POST",
        headers: {
          "Content-Type": "application/xml",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content,
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: this.buildXMLString(data)
      }).then(response => {
        if (response.ok) {
          return response.text()
        }
        throw new Error("Request failed")
      }).then(html => {
        Turbo.renderStreamMessage(html)
      }).catch(err => {
        alert(err.message || "An error occurred")
      })
    } catch (e) {
      alert(e.message || "An error occurred")
    }
  }

  available(section) {
    const el = document.getElementById(section)
    return el && !el.classList.contains("hidden")
  }

  serialize() {
    const data = { event: { line_item: [], tagged_item: [] } }

    if (this.available("general_information")) {
      this.serializeGeneralInformation(data)
    } else {
      data.event.occurred_on = this.defaultDateValue
      data.event.actor_name = this.defaultActorValue
    }

    const sections = {
      payment_source: { expense: true },
      credit_options: { expense: true },
      deposit: { expense: false },
      transfer_from: { expense: true },
      transfer_to: { expense: false },
      reallocate_from: { expense: false, reallocation: true },
      reallocate_to: { expense: true, reallocation: true }
    }

    for (const [section, options] of Object.entries(sections)) {
      if (this.available(section)) {
        this.serializeSection(data, section, options)
      }
    }

    this.serializeTags(data)
    return data
  }

  serializeGeneralInformation(data) {
    const generalInfo = document.getElementById("general_information")
    if (!generalInfo) return

    generalInfo.querySelectorAll("input, select, textarea").forEach(field => {
      if (field.name && field.name !== "amount" && field.name.trim() !== "") {
        this.addToRequest(data, field.name, field.value)
      }
    })
  }

  serializeSection(data, section, options = {}) {
    const accountId = document.getElementById(`account_for_${section}`)?.value
    let expense = 0

    const totalEl = document.getElementById("expense_total")
    if (totalEl) {
      const total = Money.parse("expense_total")
      expense = (options.expense ? -1 : 1) * total
    }

    const checkOptions = document.getElementById(`${section}.check_options`)
    if (this.sectionWantsCheckOptions(section) && checkOptions && !checkOptions.classList.contains("hidden")) {
      data.event.check_number = checkOptions.querySelector("input")?.value
    }

    const singleBucket = document.getElementById(`${section}.single_bucket`)
    if (singleBucket && !singleBucket.classList.contains("hidden")) {
      const bucketId = singleBucket.querySelector("select")?.value
      this.addLineItemRecord(data, accountId, bucketId, expense, section)
    } else {
      expense = this.addLineItems(data, accountId, section, options)
    }

    if (options.reallocation) {
      const sectionEl = document.getElementById(section)
      const primarySelect = sectionEl?.querySelector("p.primary select")
      const bucketId = primarySelect?.value
      this.addLineItemRecord(data, accountId, bucketId, -expense, "primary")
    }

    if (section === "credit_options") {
      const total = Money.parse("expense_total")
      this.addLineItemRecord(data, accountId, "r:aside", total, "aside")
    }
  }

  addLineItems(data, accountId, section, options = {}) {
    let value = 0
    const lineItems = document.getElementById(`${section}.line_items`)
    if (!lineItems) return value

    lineItems.querySelectorAll("li").forEach(row => {
      const bucketId = row.querySelector("select")?.value
      const field = row.querySelector("input[type=text]")
      if (field && field.value.trim() !== "") {
        const amount = (options.expense ? -1 : 1) * Money.parse(field)
        value += amount
        this.addLineItemRecord(data, accountId, bucketId, amount, section)
      }
    })

    return value
  }

  addLineItemRecord(data, accountId, bucketId, amount, role) {
    data.event.line_item.push({ account_id: accountId, bucket_id: bucketId, amount, role })
  }

  serializeTags(data) {
    const tags = document.getElementById("tags")
    if (tags && !tags.classList.contains("hidden")) {
      this.serializeEventTags(data)
      const tagItems = document.getElementById("tag_items")
      if (tagItems && !tagItems.classList.contains("hidden")) {
        this.serializeItemTags(data)
      }
    }
  }

  serializeEventTags(data) {
    const tagList = document.getElementById("event_tags_list")?.value?.trim()
    if (!tagList) return

    const total = this.computeTotal()
    tagList.split(",").forEach(name => {
      const trimmed = name.trim()
      if (trimmed) {
        data.event.tagged_item.push({ amount: total, tag_id: "n:" + trimmed })
      }
    })
  }

  serializeItemTags(data) {
    const taggedItems = this.taggedItemsTarget
    if (!taggedItems) return

    taggedItems.querySelectorAll("li").forEach(row => {
      const name = row.querySelector("input.tag")?.value?.trim()
      if (name) {
        const amount = Money.parse(row.querySelector("input.number"))
        data.event.tagged_item.push({ amount, tag_id: "n:" + name })
      }
    })
  }

  computeTotal() {
    const reallocateTo = document.getElementById("reallocate_to")
    const reallocateFrom = document.getElementById("reallocate_from")

    if (reallocateTo && !reallocateTo.classList.contains("hidden")) {
      return this.computeTotalForLineItems("reallocate_to")
    } else if (reallocateFrom && !reallocateFrom.classList.contains("hidden")) {
      return this.computeTotalForLineItems("reallocate_from")
    } else {
      return Money.parse("expense_total")
    }
  }

  computeTotalForLineItems(section) {
    let total = 0
    const lineItems = document.getElementById(`${section}.line_items`)
    if (lineItems) {
      lineItems.querySelectorAll("input[type=text]").forEach(field => {
        total += Money.parse(field)
      })
    }
    return total
  }

  addToRequest(obj, name, value) {
    const parts = name.replace("][", ",").replace("[", ",").replace("]", "").split(",")
    let current = obj
    for (let i = 0; i < parts.length - 1; i++) {
      if (!current[parts[i]]) current[parts[i]] = {}
      current = current[parts[i]]
    }
    current[parts[parts.length - 1]] = value
  }

  buildXMLString(data) {
    return this.buildXMLFor("event", data.event)
  }

  buildXMLFor(tag, value) {
    if (Array.isArray(value)) {
      let xml = `<${tag}s type="array">`
      value.forEach(item => { xml += this.buildXMLFor(tag, item) })
      xml += `</${tag}s>`
      return xml
    } else if (typeof value === "object" && value !== null) {
      let xml = `<${tag}>`
      for (const [key, val] of Object.entries(value)) {
        const childTag = key.replace("_", "-")
        xml += this.buildXMLFor(childTag, val)
      }
      xml += `</${tag}>`
      return xml
    } else {
      const encoded = this.encodeXML(String(value))
      return `<${tag}>${encoded}</${tag}>`
    }
  }

  encodeXML(str) {
    return str
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/'/g, "&apos;")
      .replace(/"/g, "&quot;")
  }

  sectionWantsCheckOptions(section) {
    return ["payment_source", "transfer_from", "deposit"].includes(section)
  }
}
