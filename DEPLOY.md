# Deploying BucketWise with Kamal

## Environment

```sh
export BUCKETWISE_IP_ADDRESS="1.2.3.4"
export BUCKETWISE_HOST="example.com,buckets.example.com"
export KAMAL_REGISTRY_USERNAME="dockerhub-user"
export KAMAL_REGISTRY_PASSWORD="dckr_pat_..."
```

`BUCKETWISE_HOST` is comma-separated; the first host is canonical (mailer URLs
use it) and all hosts get proxy routes and Rails `config.hosts` entries. Every
host needs a DNS `A` record pointing at the server before deploying, so Let's
Encrypt can provision a cert for it.

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

## Maintenance page

```sh
bin/kamal app maintenance --message "Upgrading, back soon"
# ... do work ...
bin/kamal app live
```

