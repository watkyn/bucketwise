# BucketWise

This file provides guidance to AI coding agents working with this repository.

## References

Two external references govern work in this repo:

1. **Fizzy — the reference implementation.**
   [basecamp/fizzy](https://github.com/basecamp/fizzy) (37signals' open-source Rails app), local clone at
   `~/dev/fizzy`. For architecture decisions, project structure, coding style, and
   Rails-idiomatic patterns, look at how Fizzy does it first. Key files to consult:
   - `~/dev/fizzy/AGENTS.md` — architecture overview and conventions
   - `~/dev/fizzy/STYLE.md` — coding style guide (follow it unless BucketWise conventions conflict)

2. **`master` branch — the behavioral reference ("what it used to do").**
   `master` is frozen at `a12e77c` and preserves the original Rails 2.3 application. It is read-only
   history: never commit to it, never merge it forward mechanically. When unsure how BucketWise is
   *supposed* to behave (accounting rules, event validation, balances, edge cases), check the old code.
   A read-only worktree lives at `../bucketwise-master` (detached at `a12e77c`); read files there
   directly, or use `git show master:<path>` from this checkout. For one-offs:
   ```sh
   git show master:app/models/event.rb        # any path on the frozen branch
   git log master --oneline                   # original history
   ```
   The Rails 8 port lives on `upgrade-again` (current working branch). Parity with `master`'s behavior
   is the goal; `TODO` tracks remaining parity gaps.

## What is BucketWise?

A personal-finance web app using envelope-style budgeting: money in an account is partitioned into
*buckets* (envelopes), with an emphasis on avoiding debt. Originally written by Jamis Buck (public
domain — see `LICENSE`).

### Domain overview

- **User** / **UserSubscription** — auth (bcrypt) and membership.
- **Subscription** — the tenancy/unit of sharing: owns accounts, events, tags, actors. Everything is
  scoped to a subscription (root redirects to "your" subscription).
- **Account** — a checking/savings/credit-card account. Has a cached `balance`, an optional credit
  `limit`, and creates default buckets (`General`/default + `aside`) on create.
- **Bucket** — an envelope within an account. Roles: `default`, `aside`, or nil. Balances are cached
  and also computable from line items (`filter_scope`).
- **Event** — a financial transaction (deposit, expense, transfer, or reallocation). The `role` is
  derived from its items unless assigned. Validates line-item role combinations (see
  `ensure_*_is_valid` in `app/models/event.rb` — this is the accounting core; be careful here).
- **LineItem** — a leg of an event against a bucket (roles like `payment_source`, `credit_options`,
  `aside`, `deposit`, `transfer_from`/`transfer_to`, `reallocate_from`/`reallocate_to`, `primary`).
  Must balance to zero per event rules.
- **AccountItem** — per-account summary of an event (one per touched account); drives account balances.
- **Actor** / **Tag** / **TaggedItem** — payee names and labels on events (tagged items may be partial
  amounts).
- **Statement** — statement periods for reconciling an account.

Balances (`accounts.balance`, `buckets.balance`) are denormalized caches — keep them in sync when
changing event/line-item flows.

### Key behaviors

- Event create/edit flows through Turbo Streams (`events#create` renders `turbo_stream`); forms are
  Stimulus-driven (`app/javascript/`), style is Tailwind.
- JSON API on `respond_to` blocks (XML API was removed in the Rails 8 port).
- `QueryFilter` provides shared filtering — string/symbol key handling matters (has regression tests).
- Known route gaps (missing views/actions, documented in `TODO`) are intentional for now — don't
  "fix" them by inventing new pages without asking.

## Development commands

```sh
bin/setup                       # install gems, prepare DB, start dev server
bin/dev                         # Puma + Tailwind watcher → http://localhost:3000
bin/rails test                  # full test suite (unit + functional + integration)
bin/rails test test/unit/event_test.rb   # single file
bin/rails db:setup              # create DB + load schema
```

Seed/bootstrap on an empty DB:

```sh
bin/rails user:create
bin/rails subscription:create USER_ID=<id>
bin/rails demo:build            # demo data (dev login: bw.demo/demo)
```

Utilities: `bin/rails data:subscription:dump ID=<id>` / `data:subscription:load FILE=... CONFIRM=1`
(export/import a subscription as YAML).

## Testing notes

- Layout: `test/unit`, `test/helpers`, `test/controllers`, `test/integration`.
- Controller tests use `ActionDispatch::IntegrationTest` and real routes; there are no Rails 2-era
  controller-test shims or `rails-controller-testing` dependency.
- Green baseline: `bin/rails test` must stay green. Browser behavior is verified by ad hoc manual testing, not Chrome system tests.
- Bug-fix discipline: every bug fix starts with a failing test that proves the bug. Write the test,
  watch it fail, then fix, then watch it pass. Never ship a bug fix without its regression test.

## Stack

Ruby 3.4.8 · Rails 8.0 · SQLite 3 (`storage/*.sqlite3`) · Hotwire (Turbo + Stimulus via importmap) ·
Tailwind CSS · propshaft · Puma. No HAML, no XML API, no RJS (removed during the port).

## Conventions

- Prefer idiomatic Rails 8 (`form_with`, ERB, `respond_to` only where actually branching).
- Match Fizzy's style (see `~/dev/fizzy/STYLE.md`) for new code: expanded conditionals over clever guard
  clauses, class methods → public → private ordering, find similar existing code before inventing.
- When porting or questioning legacy behavior, read the old code first with `git show master:...`,
  then keep/adjust the Rails 8 tests accordingly.
- Current parity status and open gaps live in `TODO` — update it as work lands.
