import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import test from "node:test"

const controllerSource = await readFile(
  new URL("../../app/javascript/controllers/events_form_controller.js", import.meta.url),
  "utf8"
)

const executableSource = controllerSource
  .replace(/^import .*\n/gm, "")
  .replace("export default class extends Controller {", "class EventsFormController extends Controller {")

const controllerModule = await import(`data:text/javascript;base64,${Buffer.from(
  `const Controller = class {};\nconst Money = new Proxy({}, { get: (_, prop) => (...args) => globalThis.__MoneyStub[prop](...args) });\n${executableSource}\nexport default EventsFormController`
).toString("base64")}`)

function stimulusObjectValue(initial) {
  let stored = JSON.stringify(initial)
  return {
    get() {
      return JSON.parse(stored)
    },
    set(value) {
      stored = JSON.stringify(value)
    }
  }
}

function selectOptions(initial = []) {
  const items = initial.map(([text, value]) => new Option(text, value))
  return new Proxy(items, {
    get(target, prop) {
      const value = target[prop]
      return typeof value === "function" ? value.bind(target) : value
    },
    set(target, prop, value) {
      if (typeof prop === "string" && /^\d+$/.test(prop)) {
        const index = Number(prop)
        if (value == null) {
          target.splice(index, 1)
        } else {
          target[index] = value
        }
        return true
      }
      target[prop] = value
      return true
    }
  })
}

function bucketSelect(section) {
  const options = selectOptions([
    ["General", "10"],
    ["Aside", "r:aside"],
    ["-- More than one --", "+"],
    ["-- Add a new bucket --", "++"]
  ])
  const select = {
    dataset: { section },
    classList: {
      contains(name) {
        return name === "splittable" || name === `bucket_for_${section}`
      }
    },
    options,
    disabled: false,
    _value: "++"
  }
  Object.defineProperty(select, "value", {
    get() { return select._value },
    set(value) { select._value = value }
  })
  Object.defineProperty(select, "selectedIndex", {
    get() {
      return options.findIndex(option => option.value == select._value)
    },
    set(index) {
      select._value = options[index]?.value ?? ""
    }
  })
  return select
}

test("naming a new bucket keeps it selected after Stimulus rereads accounts", () => {
  const originalPrompt = globalThis.prompt
  const originalDocument = globalThis.document
  const originalOption = globalThis.Option
  globalThis.Option = class Option {
    constructor(text, value) {
      this.text = text
      this.value = value == null ? "" : String(value)
    }
  }

  const accounts = {
    "1": {
      id: 1,
      name: "Checking",
      role: "checking",
      buckets: [
        { id: 10, name: "General", role: "default" },
        { id: "r:aside", name: "Aside", role: "aside" }
      ]
    }
  }
  const select = bucketSelect("payment_source")
  const controller = new controllerModule.default()
  const values = stimulusObjectValue(accounts)
  Object.defineProperty(controller, "accountsValue", values)
  controller.element = {
    querySelectorAll(selector) {
      if (selector === "#payment_source select.bucket_for_payment_source") return [select]
      return []
    }
  }

  globalThis.prompt = () => "Groceries"
  globalThis.document = {
    getElementById(id) {
      if (id === "account_for_payment_source") return { tagName: "SELECT", value: "1" }
      return null
    }
  }

  try {
    controller.handleBucketChange({ currentTarget: select })

    assert.equal(select.value, "n:Groceries")
    assert.ok(
      [...select.options].some(option => option.value === "n:Groceries" && option.text === "Groceries"),
      "new bucket should appear in the dropdown"
    )
    assert.ok(
      controller.accountsValue["1"].buckets.some(bucket => bucket.id === "n:Groceries" && bucket.name === "Groceries"),
      "new bucket must be stored on the Stimulus accounts value, not a discarded copy"
    )
  } finally {
    globalThis.prompt = originalPrompt
    globalThis.document = originalDocument
    globalThis.Option = originalOption
  }
})

test("choosing more than one shows the multiple-bucket fields", () => {
  const originalDocument = globalThis.document
  const classList = {
    values: new Set(["hidden"]),
    add(name) { this.values.add(name) },
    remove(name) { this.values.delete(name) },
    contains(name) { return this.values.has(name) }
  }
  const multipleBuckets = { classList }
  const singleBucket = { classList: { add() {}, remove() {} } }
  const select = { value: "+", dataset: { section: "payment_source" } }
  const controller = new controllerModule.default()
  const addedItems = []
  controller.addLineItemTo = section => addedItems.push(section)
  controller.updateBucketsFor = () => {}
  globalThis.document = {
    getElementById(id) {
      if (id === "payment_source.multiple_buckets") return multipleBuckets
      if (id === "payment_source.single_bucket") return singleBucket
      return null
    }
  }

  try {
    controller.handleBucketChange({ currentTarget: select })

    assert.equal(multipleBuckets.classList.contains("hidden"), false)
    assert.deepEqual(addedItems, ["payment_source", "payment_source"])
  } finally {
    globalThis.document = originalDocument
  }
})

test("choosing more than one payback account hides the section-level picker", () => {
  const originalDocument = globalThis.document
  function hiddenSet(hidden = true) {
    const values = new Set(hidden ? ["hidden"] : [])
    return {
      values,
      add(name) { this.values.add(name) },
      remove(name) { this.values.delete(name) },
      contains(name) { return this.values.has(name) }
    }
  }
  const multipleBuckets = { classList: hiddenSet() }
  const singleBucket = { classList: hiddenSet(false) }
  const accountRow = { classList: hiddenSet(false) }
  const select = { value: "+", dataset: { section: "credit_options" } }
  const controller = new controllerModule.default()
  controller.addLineItemTo = () => {}
  controller.updateBucketsFor = () => {}
  globalThis.document = {
    getElementById(id) {
      if (id === "credit_options.multiple_buckets") return multipleBuckets
      if (id === "credit_options.single_bucket") return singleBucket
      if (id === "credit_options.account") return accountRow
      return null
    }
  }

  try {
    controller.handleBucketChange({ currentTarget: select })

    assert.equal(multipleBuckets.classList.contains("hidden"), false)
    assert.equal(singleBucket.classList.contains("hidden"), true)
    assert.equal(accountRow.classList.contains("hidden"), true)
  } finally {
    globalThis.document = originalDocument
  }
})

test("serialization includes a reallocation description when general information is hidden", () => {
  const originalDocument = globalThis.document
  const memoField = { value: "Cover the car repair from savings" }
  globalThis.document = {
    getElementById(id) {
      if (id === "event_memo") return memoField
      return null
    }
  }

  try {
    const controller = new controllerModule.default()
    controller.defaultDateValue = "2026-09-23"
    controller.defaultActorValue = "Bucket reallocation"

    const data = controller.serialize()

    assert.equal(data.event.memo, memoField.value)
    assert.equal(data.event.actor_name, "Bucket reallocation")
    assert.deepEqual(data.event.line_items, [])
  } finally {
    globalThis.document = originalDocument
  }
})

test("recall fetches matching bare JSON events and rehydrates them in sequence", async () => {
  const events = [{ id: 1, role: "deposit" }, { id: 2, role: "deposit" }]
  const recalled = []
  const requested = []
  const originalFetch = globalThis.fetch

  globalThis.fetch = async url => {
    requested.push(url)
    return { json: async () => events }
  }

  try {
    const controller = new controllerModule.default()
    controller.actorNameTarget = { value: "Rhinoceros & Co." }
    controller.rehydrate = event => recalled.push(event)

    const click = { preventDefault() {}, currentTarget: { dataset: { url: "/subscriptions/1/events" } } }

    await controller.recall(click)
    await controller.recall(click)

    assert.deepEqual(recalled, events.slice(0, 2))
    assert.deepEqual(requested, [
      "/subscriptions/1/events?page=0&size=10&actor=Rhinoceros%20%26%20Co."
    ])
  } finally {
    globalThis.fetch = originalFetch
  }
})

test("multi-account repayment serializes one reserve per account", () => {
  const originalDocument = globalThis.document
  const originalMoneyStub = globalThis.__MoneyStub
  globalThis.__MoneyStub = {
    parse(value) {
      if (typeof value === "string") return 10000
      return Math.round(parseFloat(value.value) * 100)
    }
  }

  function creditRow(accountId, bucketId, amount) {
    return {
      querySelector(selector) {
        if (selector.includes("input")) return { value: amount }
        if (selector.includes("account_for")) return { value: accountId }
        if (selector.includes("bucket_for")) return { value: bucketId }
        return null
      }
    }
  }

  const rows = [creditRow("7", "21", "60.00"), creditRow("9", "31", "40.00")]
  const visible = { classList: { contains() { return false } } }
  const hidden = { classList: { contains() { return true } } }
  globalThis.document = {
    getElementById(id) {
      switch (id) {
        case "credit_options": return visible
        case "account_for_credit_options": return { value: "7" }
        case "expense_total": return {}
        case "credit_options.single_bucket": return hidden
        case "credit_options.line_items": return { querySelectorAll() { return rows } }
        default: return null
      }
    }
  }

  try {
    const controller = new controllerModule.default()
    controller.defaultDateValue = "2026-09-23"
    controller.defaultActorValue = "Splitting the bill"

    const data = controller.serialize()

    assert.deepEqual(data.event.line_items, [
      { account_id: "7", bucket_id: "21", amount: -6000, role: "credit_options" },
      { account_id: "9", bucket_id: "31", amount: -4000, role: "credit_options" },
      { account_id: "7", bucket_id: "r:aside", amount: 6000, role: "aside" },
      { account_id: "9", bucket_id: "r:aside", amount: 4000, role: "aside" }
    ])
  } finally {
    globalThis.document = originalDocument
    if (originalMoneyStub === undefined) {
      delete globalThis.__MoneyStub
    } else {
      globalThis.__MoneyStub = originalMoneyStub
    }
  }
})

test("changing a repayment row account repopulates that row buckets", () => {
  const controller = new controllerModule.default()
  const calls = []
  controller.populateBucket = (...args) => { calls.push(args) }

  const bucketSelect = { name: "repayment buckets" }
  const row = {
    querySelector(selector) {
      if (selector.includes("bucket_for")) return bucketSelect
      return null
    }
  }
  const select = { value: "5", closest: () => row }

  controller.handleRowAccountChange({ currentTarget: select })

  assert.deepEqual(calls, [[bucketSelect, "5", { reset: true, disabled: false, skipAside: true }]])
})

test("recalling a split repayment hides the section-level picker", () => {
  const originalDocument = globalThis.document
  function hiddenSet(hidden = true) {
    const values = new Set(hidden ? ["hidden"] : [])
    return {
      values,
      add(name) { this.values.add(name) },
      remove(name) { this.values.delete(name) },
      contains(name) { return this.values.has(name) }
    }
  }
  const sectionEl = { classList: hiddenSet() }
  const multipleBuckets = { classList: hiddenSet() }
  const singleBucket = { classList: hiddenSet(false) }
  const accountRow = { classList: hiddenSet(false) }
  const acctSelect = { value: "" }
  const added = []
  const controller = new controllerModule.default()
  controller.accountsValue = {
    7: { id: 7, name: "Checking", role: "checking", buckets: [] },
    9: { id: 9, name: "Savings", role: null, buckets: [] }
  }
  controller.updateBucketsFor = () => {}
  controller.addLineItemTo = (section, item) => { added.push([section, item]) }
  globalThis.document = {
    getElementById(id) {
      switch (id) {
        case "credit_options": return sectionEl
        case "account_for_credit_options": return acctSelect
        case "credit_options.check_options": return null
        case "credit_options.multiple_buckets": return multipleBuckets
        case "credit_options.single_bucket": return singleBucket
        case "credit_options.account": return accountRow
        default: return null
      }
    }
  }

  try {
    const items = [
      { role: "credit_options", account_id: 7, bucket_id: 21, amount: -6000 },
      { role: "credit_options", account_id: 9, bucket_id: 31, amount: -4000 }
    ]
    controller.rehydrateSection("credit_options", { line_items: items })

    assert.equal(accountRow.classList.contains("hidden"), true)
    assert.deepEqual(added.map(([section]) => section), ["credit_options", "credit_options"])
    assert.deepEqual(added.map(([, item]) => item.account_id), [7, 9])
  } finally {
    globalThis.document = originalDocument
  }
})

test("validation errors use labels that make sense for the transaction type", async () => {
  for (const [role, expectedLabel] of [
    ["expense", "Payee"],
    ["deposit", "Deposit source"],
    ["transfer", "Transfer description"]
  ]) {
    const controller = new controllerModule.default()
    controller.element = {
      querySelector(selector) {
        return selector === `.${role}_label:not(.hidden)` ? {} : null
      }
    }
    const response = {
      status: 422,
      clone() {
        return { json: async () => ({ actor_name: ["can't be blank"], line_items: ["must be provided"] }) }
      }
    }

    assert.equal(
      await controller.errorMessage(response),
      `${expectedLabel} can't be blank\nTransaction details must be provided`
    )
  }
})

function absorbTestSetup(amounts, totalCents) {
  const originalDocument = globalThis.document
  const originalMoneyStub = globalThis.__MoneyStub
  globalThis.__MoneyStub = {
    parse(fieldOrValue) {
      if (typeof fieldOrValue === "string") return totalCents
      const unsigned = String(fieldOrValue.value ?? "").replace(/[^-+\d.]/g, "").replace(/^-/, "")
      return Math.round(parseFloat(unsigned || "0") * 100)
    },
    dollars(cents) {
      return (Math.abs(cents) / 100).toFixed(2)
    },
    formatValue(cents) {
      return (cents / 100).toFixed(2)
    }
  }

  const list = { id: "payment_source.line_items", inputs: [] }
  function makeRow(amount) {
    const input = { value: amount }
    const hidden = new Set(["hidden"])
    const button = {
      classList: {
        toggle(name, force) {
          if (force) hidden.add(name)
          else hidden.delete(name)
        },
        contains(name) { return hidden.has(name) }
      },
      title: "",
      ariaLabel: "",
      dataTip: "",
      setAttribute(name, value) {
        if (name === "aria-label") this.ariaLabel = value
        if (name === "data-tip") this.dataTip = value
      },
      closest(selector) {
        if (selector === "li") return row
        return null
      }
    }
    const row = {
      input,
      button,
      querySelector(selector) {
        if (selector === "input[type=text]") return input
        if (selector === ".absorb-remainder") return button
        return null
      },
      closest(selector) {
        if (selector === "ol") return list
        return null
      }
    }
    list.inputs.push(input)
    return row
  }

  const rows = amounts.map(makeRow)
  list.querySelectorAll = selector => selector === "li" ? rows : list.inputs
  const message = { html: "" }
  const unassignedEl = {}
  Object.defineProperty(unassignedEl, "innerHTML", {
    get() { return message.html },
    set(value) { message.html = value }
  })
  globalThis.document = {
    getElementById(id) {
      if (id === "payment_source") return {}
      if (id === "payment_source.line_items") return list
      if (id === "payment_source.unassigned") return unassignedEl
      return null
    }
  }

  return {
    rows,
    message,
    restore() {
      globalThis.document = originalDocument
      if (originalMoneyStub === undefined) delete globalThis.__MoneyStub
      else globalThis.__MoneyStub = originalMoneyStub
    }
  }
}

test("target button absorbs the unallocated remainder into its own row", () => {
  const setup = absorbTestSetup(["40.00", "45.00"], 10000)
  try {
    const controller = new controllerModule.default()
    controller.updateUnassigned()

    for (const row of setup.rows) {
      assert.equal(row.button.classList.contains("hidden"), false)
      assert.equal(row.button.dataTip, "Absorb $15.00 into this bucket")
      assert.equal(row.button.ariaLabel, "Absorb $15.00 into this bucket")
    }
    assert.match(setup.message.html, /15\.00.*remains unallocated/)

    controller.absorbRemainder({ preventDefault() {}, currentTarget: setup.rows[0].button })

    assert.equal(setup.rows[0].input.value, "55.00")
    assert.equal(setup.rows[1].input.value, "45.00")
    for (const row of setup.rows) {
      assert.equal(row.button.classList.contains("hidden"), true)
    }
    assert.equal(setup.message.html, "")
  } finally {
    setup.restore()
  }
})

test("target button sheds the overage from its own row", () => {
  const setup = absorbTestSetup(["60.00", "55.00"], 10000)
  try {
    const controller = new controllerModule.default()
    controller.updateUnassigned()

    assert.equal(setup.rows[0].button.dataTip, "Remove $15.00 overage from this bucket")
    assert.match(setup.message.html, /overallocated/)

    controller.absorbRemainder({ preventDefault() {}, currentTarget: setup.rows[0].button })

    assert.equal(setup.rows[0].input.value, "45.00")
    assert.equal(setup.rows[1].input.value, "55.00")
  } finally {
    setup.restore()
  }
})

test("target button stays hidden with a single row or a balanced split", () => {
  for (const [amounts, total] of [[["40.00"], 10000], [["60.00", "40.00"], 10000]]) {
    const setup = absorbTestSetup(amounts, total)
    try {
      const controller = new controllerModule.default()
      controller.updateUnassigned()

      for (const row of setup.rows) {
        assert.equal(row.button.classList.contains("hidden"), true)
      }
    } finally {
      setup.restore()
    }
  }
})

test("target button refuses an absorption that would empty a row or drive it negative", () => {
  for (const amounts of [["10.00", "120.00"], ["30.00", "100.00"]]) {
    const setup = absorbTestSetup(amounts, 10000)
    try {
      const controller = new controllerModule.default()
      controller.updateUnassigned()

      assert.equal(setup.rows[0].button.classList.contains("hidden"), true)
      assert.equal(setup.rows[1].button.classList.contains("hidden"), false)

      controller.absorbRemainder({ preventDefault() {}, currentTarget: setup.rows[0].button })

      assert.equal(setup.rows[0].input.value, amounts[0])
      assert.equal(setup.rows[1].input.value, amounts[1])
      assert.match(setup.message.html, /overallocated/)
    } finally {
      setup.restore()
    }
  }
})
