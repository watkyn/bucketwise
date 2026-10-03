#!/usr/bin/env ruby

# Copy the local sqlite database to the server where the app will look for it
# (via the /root/bucketwise:/rails/storage bind mount in config/deploy.yml).
# Plain ssh/scp — independent of Kamal. Same pattern as mlf-server's
# scripts/copy_db_to_server.rb.
#
# Usage:
#   export BUCKETWISE_IP_ADDRESS=1.2.3.4
#   bin/rails db:migrate              # make sure the local db schema is current
#   scripts/copy_db_to_server.rb      # copies storage/development.sqlite3
#   DB_FILE=storage/production.sqlite3 scripts/copy_db_to_server.rb

ip_address = ENV["BUCKETWISE_IP_ADDRESS"] or abort "export BUCKETWISE_IP_ADDRESS first"
db_file = ENV.fetch("DB_FILE", "storage/development.sqlite3")
abort "#{db_file} does not exist" unless File.exist?(db_file)

# copy the database to the server where the app will look for it
`ssh root@#{ip_address} "mkdir -p /root/bucketwise"`
system("scp", db_file, "root@#{ip_address}:/root/bucketwise/production.sqlite3") or abort "scp failed"
`ssh root@#{ip_address} "chmod -R 777 /root/bucketwise"`

puts "all done, login to verify: ssh root@#{ip_address}"
