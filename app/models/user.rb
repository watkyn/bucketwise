class User < ApplicationRecord
  include OptionHandler

  has_many :user_subscriptions, dependent: :destroy
  has_many :subscriptions, through: :user_subscriptions

  has_secure_password

  validates :user_name, uniqueness: true, allow_nil: true
  validates :user_name, presence: true

  # Keep legacy SHA1 method for migration if password_digest blank but password_hash present
  def self.password_hash_for(password, salt)
    require 'digest/sha1'
    Digest::SHA1.hexdigest(salt + password)
  end

  def self.authenticate(user_name, password)
    user = find_by(user_name: user_name)
    return nil unless user

    # Prefer bcrypt
    if user.password_digest.present?
      user.authenticate(password) ? user : nil
    elsif user.password_hash.present? && user.salt.present?
      # Legacy SHA1 fallback
      hash = password_hash_for(password, user.salt)
      hash == user.password_hash ? user : nil
    else
      nil
    end
  end

  # Override to hide password_digest
  def as_json(options={})
    options[:except] = Array(options[:except]) + [:password_digest, :password_hash, :salt]
    super(options)
  end
end
