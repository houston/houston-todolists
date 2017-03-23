class TodoList < ActiveRecord::Base
  include Houston::Props

  default_scope -> { where(destroyed_at: nil) }

  belongs_to :authorization
  has_and_belongs_to_many :goals
  has_many :items, class_name: "TodoListItem"

  validates :name, :authorization_id, :remote_id, presence: true

  class << self
    def sync(expected_lists)
      Houston.benchmark("[todolist:sync:lists] #{expected_lists.length}") do
        expected_ids = expected_lists.map { |list| list[:remote_id] }
        existing_ids = with_destroyed.pluck(:remote_id)

        with_destroyed.where(remote_id: existing_ids & expected_ids).each do |existing_list|
          attributes = expected_lists.find { |list| list[:remote_id] == existing_list.remote_id }
          existing_list.update_attributes!(attributes)
        end

        expected_lists.each do |attributes|
          next if existing_ids.member? attributes[:remote_id]
          next if attributes[:destroyed]
          unless (list = create(attributes)).persisted?
            Rails.logger.debug("[todolist:sync:lists] list #{attributes.inspect} could not be created:\n#{list.errors.full_messages.join("\n")}")
          end
        end
      end
    end

    def with_destroyed
      unscope(where: :destroyed_at)
    end
  end

  def destroyed?
    destroyed_at.present?
  end

  def destroyed=(value)
    return if value == destroyed?
    self.destroyed_at = value ? Time.now : nil
  end

end
