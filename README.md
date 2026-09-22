# BucketWise

A personal-finance web app built with Ruby on Rails, using envelope-style
budgeting (partition accounts into buckets) and an emphasis on avoiding debt.
Originally written by Jamis Buck — see `LICENSE` (public domain).

## Requirements

- Ruby 3.4.8 (see `.ruby-version`)
- Rails 8.0
- SQLite 3

## Setup

```sh
bin/setup              # install gems, prepare the database, start dev server
bin/rails db:setup     # (alternative) create the database and load the schema
bin/dev                # start Puma + Tailwind watcher on http://localhost:3000
```

If the database is empty, create a user and a subscription first:

```sh
bin/rails user:create
bin/rails subscription:create USER_ID=<id>
```

## Tests

```sh
bin/rails test
```
