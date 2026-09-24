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
