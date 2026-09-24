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
  `const Controller = class {};\nconst Money = {};\n${executableSource}\nexport default EventsFormController`
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
