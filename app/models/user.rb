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

    if user.password_digest.present?
      user.authenticate(password) ? user : nil
    elsif user.password_hash.present? && user.salt.present?
      return nil unless password.is_a?(String)

      hash = password_hash_for(password, user.salt)
      return nil unless ActiveSupport::SecurityUtils.secure_compare(hash, user.password_hash)

      # BCrypt only uses the first 72 bytes. Keep longer legacy passwords
      # authenticatable rather than silently migrating them to a truncated password.
      if password.bytesize <= 72
        user.password = password
        user.update_columns(
          password_digest: user.password_digest,
          password_hash: nil,
          salt: nil,
          updated_at: Time.current
        )
      end

      user
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
