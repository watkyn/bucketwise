#!/usr/bin/env ruby

# Pull a fresh copy of the production sqlite database from the server to this
# machine (opposite of scripts/copy_db_to_server.rb). The snapshot is taken
# with sqlite3's .backup (online backup API) inside the running container, so
# it is transactionally consistent and the app does NOT need to be stopped.
# The snapshot is written into /rails/storage (the /root/bucketwise bind
# mount), scp'd down, then removed from the server.
#
# Usage:
#   export BUCKETWISE_IP_ADDRESS=1.2.3.4
#   scripts/backup_db_from_server.rb            # -> backups/production-20261020-153000.sqlite3
#   OUT_DIR=~/Desktop scripts/backup_db_from_server.rb
#   DB_FILE=production_cache.sqlite3 scripts/backup_db_from_server.rb

require "fileutils"

ip_address = ENV["BUCKETWISE_IP_ADDRESS"] or abort "export BUCKETWISE_IP_ADDRESS first"
db_file = ENV.fetch("DB_FILE", "production.sqlite3")
abort "unexpected db file #{db_file.inspect}" unless db_file.match?(/\Aproduction\w*\.sqlite3\z/)

timestamp = Time.now.strftime("%Y%m%d-%H%M%S")
snapshot = "backup-#{timestamp}.sqlite3"

system("bin/kamal", "app", "exec", "--reuse",
  "sqlite3 /rails/storage/#{db_file} .backup /rails/storage/#{snapshot}") or abort "snapshot on server failed"

out_dir = File.expand_path(ENV.fetch("OUT_DIR", "backups"))
FileUtils.mkdir_p(out_dir)
local = File.join(out_dir, "#{db_file.delete_suffix(".sqlite3")}-#{timestamp}.sqlite3")

system("scp", "root@#{ip_address}:/root/bucketwise/#{snapshot}", local) or abort "scp failed"
system("ssh", "root@#{ip_address}", "rm -f /root/bucketwise/#{snapshot}") or abort "cleanup failed"

integrity = IO.popen([ "sqlite3", local, "PRAGMA integrity_check" ], &:read).to_s.strip rescue ""
abort "integrity check failed for #{local}" unless integrity == "ok"

puts "backed up to #{local}"
