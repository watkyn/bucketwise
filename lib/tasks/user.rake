namespace :user do
  def ask(prompt)
    $stdout.print prompt
    $stdin.gets.to_s.strip
  end

  def ask_password(prompt)
    require "io/console"
    if $stdin.tty?
      $stdin.getpass(prompt).to_s.strip
    else
      ask(prompt)
    end
  end

  desc "Create a new user."
  task create: :environment do
    name = ENV["NAME"] || ask("Name: ")
    email = ENV["EMAIL"] || ask("E-mail: ")
    user_name = ENV["USERNAME"] || ask("User name: ")
    password = ENV["PASSWORD"] || ask_password("Password: ")
    abort "Password cannot be blank" if password.blank?

    user = User.create!(name: name, email: email,
      user_name: user_name, password: password)

    puts "User `#{user_name}' created: ##{user.id}"

    unless ENV["SKIP_SUBSCRIPTION"]
      subscription = Subscription.create!(owner: user)
      user.subscriptions << subscription
      puts "Subscription ##{subscription.id} created for `#{user_name}'"
    end
  end

  desc "List users (PAGE env var selects which page of users)"
  task list: :environment do
    page = ENV["PAGE"].to_i

    users = User.order(:user_name).limit(25).offset(page * 25)

    puts "page ##{page}"
    puts "---------------"

    if users.empty?
      puts "no users found"
    else
      users.each do |user|
        puts "##{user.id}: \"#{user.name}\" <#{user.email}>"
      end
    end
  end

  desc "Report info about particular user (USERNAME env var)."
  task show: :environment do
    user = User.find_by(user_name: ENV["USERNAME"])

    if user
      puts "##{user.id}: \"#{user.name}\" <#{user.email}>"
    else
      puts "No user with that user name."
    end
  end

  desc "List all subscriptions for the given user (USER_ID env var)"
  task subscriptions: :environment do
    user = User.find(ENV["USER_ID"])

    if user.subscriptions.empty?
      puts "No subscriptions for `#{user.user_name}' ##{user.id}"
    else
      puts "Subscriptions for `#{user.user_name}' ##{user.id}"
      user.subscriptions.each do |sub|
        puts "##{sub.id}"
      end
    end
  end

  desc "Grant access to a specific subscription id (USER_ID env var, SUBSCRIPTION_ID env var)."
  task grant: :environment do
    subscription = Subscription.find(ENV["SUBSCRIPTION_ID"])
    user = User.find(ENV["USER_ID"])
    user.subscriptions << subscription
    puts "user `#{user.user_name}' granted access to subscription ##{subscription.id}"
  end

  desc "Revoke access to a specific subscription id (USER_ID env var, SUBSCRIPTION_ID env var)."
  task revoke: :environment do
    subscription = Subscription.find(ENV["SUBSCRIPTION_ID"])
    user = User.find(ENV["USER_ID"])
    user.subscriptions.delete(subscription)
    puts "user `#{user.user_name}' revoked access to subscription ##{subscription.id}"
  end
end
