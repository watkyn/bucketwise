# Deploying BucketWise with Kamal

## Environment

```sh
export BUCKETWISE_IP_ADDRESS="1.2.3.4"
export KAMAL_REGISTRY_PASSWORD="dckr_pat_..."
```

## Architecture

`builder.arch` is `amd64`

## Database

Optional, before first deploy or with the app stopped:

```sh
bin/rails db:migrate
scripts/copy_db_to_server.rb
DB_FILE=storage/production.sqlite3 scripts/copy_db_to_server.rb
```

## Deploy

```sh
bin/kamal setup    # first time only
bin/kamal deploy
```

## Day-to-day

```sh
bin/kamal deploy
bin/kamal console
bin/kamal shell
bin/kamal logs
bin/kamal dbc
```
