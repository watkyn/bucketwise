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

const moneySource = await readFile(new URL("../../app/javascript/money.js", import.meta.url), "utf8")
const { Money } = await import(`data:text/javascript;base64,${Buffer.from(moneySource).toString("base64")}`)

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

function percentTestSetup(rowValues, total = "3000.00") {
  const originalDocument = globalThis.document
  const originalMoneyStub = globalThis.__MoneyStub
  globalThis.__MoneyStub = Money

  function classList(hidden = true) {
    const names = new Set(hidden ? ["hidden"] : [])
    return {
      add(name) { names.add(name) },
      remove(name) { names.delete(name) },
      toggle(name, force) {
        if (force) names.add(name)
        else names.delete(name)
      },
      contains(name) { return names.has(name) }
    }
  }

  function makeRow(value) {
    const input = { value, focus() {} }
    const bucket = { value: "10" }
    const unit = { textContent: "$" }
    const computed = {
      textContent: "",
      classList: classList()
    }
    return {
      input,
      unit,
      computed,
      querySelector(selector) {
        if (selector === "input[type=text]" || selector === "input") return input
        if (selector === "select") return bucket
        if (selector === ".line-item-unit") return unit
        if (selector === ".line-item-computed") return computed
        return null
      }
    }
  }

  const rows = rowValues.map(makeRow)
  const list = {
    querySelectorAll: selector => selector === "li" ? rows : rows.map(row => row.input),
    appendChild(row) { rows.push(row) },
    set innerHTML(value) {
      assert.equal(value, "")
      rows.length = 0
    }
  }
  const visibleSection = { classList: classList(false) }
  const totalField = { value: total }
  const nodes = {
    expense_total: totalField,
    payment_source: visibleSection,
    "payment_source.line_items": list,
    "payment_source.unassigned": { innerHTML: "" },
    "template.payment_source": { innerHTML: "" }
  }
  globalThis.document = {
    getElementById(id) { return nodes[id] || null },
    createElement() { return makeRow("") }
  }

  const controller = new controllerModule.default()
  controller.hasPercentToggleTarget = true
  controller.percentToggleTarget = {
    style: {},
    title: "",
    attributes: { "aria-pressed": "false" },
    setAttribute(name, value) { this.attributes[name] = String(value) }
  }

  return {
    rows,
    controller,
    totalField,
    nodes,
    classList,
    restore() {
      globalThis.document = originalDocument
      if (originalMoneyStub === undefined) delete globalThis.__MoneyStub
      else globalThis.__MoneyStub = originalMoneyStub
    }
  }
}

test("percent rows resolve against the header total", () => {
  const setup = percentTestSetup(["10", "20.50"])
  try {
    setup.controller.percentOn = true

    assert.equal(setup.controller.computeTotalForLineItems("payment_source"), 91500)
    assert.equal(setup.controller.rowCents("payment_source", { value: "10" }), 30000)
  } finally {
    setup.restore()
  }
})

test("dollar rows are unaffected when percent mode is off", () => {
  const setup = percentTestSetup(["300.00", "615.00"])
  try {
    assert.equal(setup.controller.computeTotalForLineItems("payment_source"), 91500)
  } finally {
    setup.restore()
  }
})

test("percent toggle converts a split to percent and back", () => {
  const setup = percentTestSetup(["1350.00", "1650.00"])
  try {
    const click = { preventDefault() {} }

    setup.controller.togglePercentMode(click)

    assert.equal(setup.controller.percentOn, true)
    assert.deepEqual(setup.rows.map(row => row.input.value), ["45", "55"])
    assert.deepEqual(setup.rows.map(row => row.unit.textContent), ["%", "%"])
    assert.equal(setup.controller.percentToggleTarget.title, "Use dollar amounts")
    assert.equal(setup.controller.percentToggleTarget.style.backgroundColor, "black")
    assert.equal(setup.controller.percentToggleTarget.style.color, "white")
    assert.equal(setup.controller.percentToggleTarget.style.borderColor, "black")

    setup.controller.togglePercentMode(click)

    assert.equal(setup.controller.percentOn, false)
    assert.deepEqual(setup.rows.map(row => row.input.value), ["1,350.00", "1,650.00"])
    assert.deepEqual(setup.rows.map(row => row.unit.textContent), ["$", "$"])
    assert.equal(setup.controller.percentToggleTarget.title, "Use percentages")
    assert.equal(setup.controller.percentToggleTarget.style.color, "#9ca3af")
    assert.equal(setup.controller.percentToggleTarget.style.borderColor, "#e5e7eb")
  } finally {
    setup.restore()
  }
})

test("uneven percents keep only the decimals they need", () => {
  const setup = percentTestSetup(["1.00", "2.00"], "3.00")
  try {
    setup.controller.togglePercentMode({ preventDefault() {} })

    assert.deepEqual(setup.rows.map(row => row.input.value), ["33.33", "66.67"])
  } finally {
    setup.restore()
  }
})

test("percent conversions preserve cents", () => {
  const setup = percentTestSetup(["1000.00", "2000.00"])
  try {
    setup.controller.togglePercentMode({ preventDefault() {} })
    assert.equal(setup.controller.rowCents("payment_source", setup.rows[0].input), 100000)
    assert.equal(setup.controller.computeTotalForLineItems("payment_source"), 300000)

    setup.controller.togglePercentMode({ preventDefault() {} })
    assert.deepEqual(setup.rows.map(row => row.input.value), ["1,000.00", "2,000.00"])
  } finally {
    setup.restore()
  }
})

test("a zero total does not erase dollar amounts when percent mode is requested", () => {
  const setup = percentTestSetup(["40.00", "60.00"], "0")
  try {
    setup.controller.togglePercentMode({ preventDefault() {} })

    assert.deepEqual(setup.rows.map(row => row.input.value), ["40.00", "60.00"])
    assert.ok(!setup.controller.percentOn)
  } finally {
    setup.restore()
  }
})

test("reset clears split rows but leaves the percent toggle to the user", () => {
  const setup = percentTestSetup(["1350.00", "1650.00"])
  try {
    setup.controller.togglePercentMode()
    assert.ok(!setup.rows[0].computed.classList.contains("hidden"))

    setup.controller.reset()

    assert.equal(setup.rows.length, 0)
    assert.equal(setup.controller.percentOn, true)
    assert.equal(setup.controller.percentToggleTarget.attributes["aria-pressed"], "true")
  } finally {
    setup.restore()
  }
})

test("percent remainder absorption clears the difference to the cent", () => {
  const setup = absorbTestSetup(["33.33", "66.67"], 300000)
  try {
    const controller = new controllerModule.default()
    controller.percentOn = true
    setup.rows[1].input.value = "66.666"
    controller.absorbRemainder({ preventDefault() {}, currentTarget: setup.rows[0].button })

    assert.equal(controller.remainderFor("payment_source"), 0)
  } finally {
    setup.restore()
  }
})

test("invalid percent input resolves to zero rather than poisoning totals", () => {
  const setup = percentTestSetup([".", "10oops", "Infinity", " "])
  try {
    setup.controller.percentOn = true

    assert.equal(setup.controller.computeTotalForLineItems("payment_source"), 0)
  } finally {
    setup.restore()
  }
})

test("percent labels and serialized cents follow changes to the header total", () => {
  const setup = percentTestSetup(["1350.00", "1650.00"])
  try {
    setup.controller.togglePercentMode()
    setup.totalField.value = "100.01"
    setup.controller.updateAmount()

    assert.deepEqual(setup.rows.map(row => row.computed.textContent), ["≈ $45.00", "≈ $55.01"])

    const data = { event: { line_items: [] } }
    setup.controller.addLineItems(data, "1", "payment_source", { expense: true })
    assert.deepEqual(data.event.line_items.map(item => item.amount), [-4500, -5501])
  } finally {
    setup.restore()
  }
})

test("recall keeps dollar amounts and leaves percent mode off", () => {
  for (const amounts of [[135000, 165000], [135000, 100000]]) {
    const setup = percentTestSetup([])
    try {
      setup.controller.accountsValue = {}
      setup.controller.updateBucketsFor = () => {}
      setup.controller.rehydrateSection("payment_source", {
        line_items: amounts.map(amount => ({ role: "payment_source", account_id: 1, bucket_id: 10, amount: -amount }))
      })

      assert.equal(setup.controller.percentOn, false)
      assert.deepEqual(setup.rows.map(row => row.input.value), amounts.map(amount => Money.formatValue(amount)))
    } finally {
      setup.restore()
    }
  }

  const single = percentTestSetup([])
  try {
    single.controller.accountsValue = {}
    single.controller.updateBucketsFor = () => {}
    single.controller.rehydrateSection("payment_source", {
      line_items: [{ role: "payment_source", account_id: 1, bucket_id: 10, amount: -300000 }]
    })

    assert.equal(single.controller.percentOn, false)
    assert.equal(single.rows.length, 0)
  } finally {
    single.restore()
  }
})

test("recall leaves the percent toggle to the user", () => {
  const setup = percentTestSetup([])
  Object.assign(setup.nodes, {
    event_occurred_on: { value: "" },
    event_actor_name: { value: "" },
    event_memo: { value: "" },
    account_for_payment_source: { value: "" },
    "payment_source.single_bucket": { classList: setup.classList(false), querySelector: () => ({}) },
    "payment_source.multiple_buckets": { classList: setup.classList() }
  })
  const { controller } = setup
  controller.element = { querySelectorAll: () => [] }
  controller.hasExpenseTotalTarget = true
  controller.expenseTotalTarget = setup.totalField
  controller.accountsValue = {}
  controller.updateBucketsFor = () => {}
  controller.populateBucket = () => {}
  controller.togglePercentMode({ preventDefault() {} })
  assert.equal(controller.percentToggleTarget.attributes["aria-pressed"], "true")

  try {
    controller.rehydrate({
      role: "expense",
      value: 300000,
      memo: "",
      tagged_items: [],
      line_items: [
        { role: "payment_source", account_id: 1, bucket_id: 10, amount: -135000 },
        { role: "payment_source", account_id: 1, bucket_id: 11, amount: -165000 }
      ]
    })

    assert.equal(controller.percentOn, true)
    assert.equal(controller.percentToggleTarget.attributes["aria-pressed"], "true")
    assert.deepEqual(setup.rows.map(row => row.input.value), ["45", "55"])
    assert.equal(controller.computeTotalForLineItems("payment_source"), 300000)
  } finally {
    setup.restore()
  }
})

test("recall across event types never changes the toggle", () => {
  const setup = percentTestSetup([])
  const depositRows = []
  const depositList = {
    querySelectorAll: selector => selector === "li" ? depositRows : depositRows.map(row => row.input),
    appendChild(row) { depositRows.push(row) },
    set innerHTML(value) {
      assert.equal(value, "")
      depositRows.length = 0
    }
  }
  Object.assign(setup.nodes, {
    event_occurred_on: { value: "" },
    event_actor_name: { value: "" },
    event_memo: { value: "" },
    account_for_deposit: { value: "" },
    "deposit.line_items": depositList,
    "deposit.unassigned": { innerHTML: "" },
    "template.deposit": { innerHTML: "" },
    "deposit.single_bucket": { classList: setup.classList(false), querySelector: () => ({}) },
    "deposit.multiple_buckets": { classList: setup.classList() }
  })
  setup.nodes.deposit = { classList: setup.classList() }
  const { controller } = setup
  controller.element = { querySelectorAll: () => [] }
  controller.hasExpenseTotalTarget = true
  controller.expenseTotalTarget = setup.totalField
  controller.hasPaymentSourceTarget = true
  controller.paymentSourceTarget = setup.nodes.payment_source
  controller.hasDepositTarget = true
  controller.depositTarget = setup.nodes.deposit
  controller.accountsValue = {}
  controller.updateBucketsFor = () => {}
  controller.populateBucket = () => {}
  controller.percentOn = true
  controller.syncPercentToggle()
  assert.equal(controller.percentToggleTarget.attributes["aria-pressed"], "true")

  try {
    controller.rehydrate({
      role: "deposit",
      value: 300000,
      memo: "",
      tagged_items: [],
      line_items: [
        { role: "deposit", account_id: 1, bucket_id: 10, amount: 135000 },
        { role: "deposit", account_id: 1, bucket_id: 11, amount: 165000 }
      ]
    })

    assert.equal(controller.percentOn, true)
    assert.equal(controller.percentToggleTarget.attributes["aria-pressed"], "true")
    assert.deepEqual(depositRows.map(row => row.input.value), ["45", "55"])
    assert.equal(controller.computeTotalForLineItems("deposit"), 300000)
  } finally {
    setup.restore()
  }
})

test("each recall replaces the form with the previous transaction instead of accumulating split rows", async () => {
  const setup = percentTestSetup([])
  const originalFetch = globalThis.fetch
  const { controller, nodes, classList } = setup
  const bucket = { value: "" }
  const events = [
    { id: 3, amounts: [6000, 4000] },
    { id: 2, amounts: [2000, 3000, 5000] },
    { id: 1, amounts: [10000] }
  ].map(({ id, amounts }) => ({
    id, role: "expense", value: 10000, memo: `Transaction ${id}`, tagged_items: [],
    line_items: amounts.map((amount, index) => ({
      role: "payment_source", account_id: id === 1 ? 2 : 1, bucket_id: index + 10, amount: -amount
    }))
  }))
  const requested = []
  globalThis.fetch = async url => {
    requested.push(url)
    return { json: async () => events }
  }
  Object.assign(nodes, {
    event_occurred_on: { value: "2026-10-14" },
    event_actor_name: { value: "Groceries", focus() {} },
    event_memo: { value: "" },
    account_for_payment_source: {
      get value() { return this._value || "" },
      set value(value) { this._value = String(value) }
    },
    "payment_source.single_bucket": { classList: classList(false), querySelector: () => bucket },
    "payment_source.multiple_buckets": { classList: classList() },
    "payment_source.check_options": { classList: classList(), querySelector: () => null },
    "payment_source.repayment_options": { classList: classList() }
  })
  controller.element = { querySelectorAll: () => [] }
  controller.hasPaymentSourceTarget = true
  controller.paymentSourceTarget = nodes.payment_source
  controller.hasExpenseTotalTarget = true
  controller.expenseTotalTarget = setup.totalField
  controller.hasActorNameTarget = true
  controller.actorNameTarget = nodes.event_actor_name
  controller.hasRecallEventTarget = true
  controller.recallEventTarget = { classList: classList() }
  controller.hasFormTarget = true
  controller.formTarget = {
    reset() {
      setup.totalField.value = ""
      nodes.event_occurred_on.value = ""
      nodes.event_actor_name.value = ""
      setup.rows.forEach(row => { row.input.value = "" })
    }
  }
  controller.accountsValue = {
    1: { id: 1, role: "checking", buckets: [] },
    2: { id: 2, role: "credit-card", buckets: [] }
  }
  controller.updateBucketsFor = () => {}
  controller.populateBucket = () => {}
  controller.selectBucket = (select, value) => { select.value = String(value) }
  controller.connect()

  try {
    const click = { preventDefault() {}, currentTarget: { dataset: { url: "/subscriptions/1/events" } } }
    for (const index of [0, 1, 2, 0]) {
      await controller.recall(click)

      const expected = events[index]
      assert.equal(controller.currentEvent, index)
      assert.equal(nodes.event_memo.value, expected.memo)
      assert.equal(nodes.event_occurred_on.value, "2026-10-14")
      assert.equal(nodes.event_actor_name.value, "Groceries")
      const split = expected.line_items.length > 1
      assert.equal(setup.rows.length, split ? expected.line_items.length : 0)
      assert.equal(nodes["payment_source.single_bucket"].classList.contains("hidden"), split)
      assert.equal(nodes["payment_source.multiple_buckets"].classList.contains("hidden"), !split)
      assert.equal(nodes["payment_source.check_options"].classList.contains("hidden"), index === 2)
      assert.equal(nodes["payment_source.repayment_options"].classList.contains("hidden"), index !== 2)
      assert.equal(controller.percentToggleTarget.attributes["aria-pressed"], "false")
      assert.deepEqual(controller.serialize().event.line_items, expected.line_items.map(item => ({
        ...item, account_id: String(item.account_id), bucket_id: String(item.bucket_id)
      })))
    }
    assert.equal(requested.length, 1)
  } finally {
    globalThis.fetch = originalFetch
    setup.restore()
  }
})

test("reset clears every section's dynamic rows and restores single-bucket and account controls", () => {
  const setup = percentTestSetup([])
  try {
    for (const section of ["payment_source", "credit_options", "deposit", "transfer_from", "transfer_to", "reallocate_from", "reallocate_to"]) {
      const { nodes, classList } = setup
      nodes[`${section}.line_items`] = { innerHTML: "old rows" }
      for (const control of ["account", "single_bucket", "multiple_buckets", "check_options", "repayment_options"]) {
        nodes[`${section}.${control}`] = { classList: classList(control === "account" || control === "single_bucket") }
      }
    }
    setup.controller.updateUnassigned = () => {}

    setup.controller.reset()

    for (const section of ["payment_source", "credit_options", "deposit", "transfer_from", "transfer_to", "reallocate_from", "reallocate_to"]) {
      assert.equal(setup.nodes[`${section}.line_items`].innerHTML, "")
      for (const control of ["account", "single_bucket"]) {
        assert.ok(!setup.nodes[`${section}.${control}`].classList.contains("hidden"))
      }
      for (const control of ["multiple_buckets", "check_options", "repayment_options"]) {
        assert.ok(setup.nodes[`${section}.${control}`].classList.contains("hidden"))
      }
    }
  } finally {
    setup.restore()
  }
})
