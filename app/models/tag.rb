class Tag < ApplicationRecord
  belongs_to :subscription

  has_many :tagged_items, dependent: :delete_all

  validates :name, presence: true
  validates :name, uniqueness: { scope: :subscription_id, case_sensitive: false }

  def self.template
    new(name: "name of tag")
  end

  def assimilate(tag)
    raise ActiveRecord::RecordNotSaved, "cannot assimilate self" if tag == self

    transaction do
      TaggedItem.where(tag_id: tag.id).update_all(tag_id: id)
      tag.tagged_items.reset if tag.tagged_items.loaded?
      update_column(:balance, balance + tag.balance)
      tag.destroy
    end
  end

  def as_json(options={})
    options[:only] = Array(options[:only]) + [:name] if new_record?
    super(options)
  end
end
