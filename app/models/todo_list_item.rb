class TodoListItem < ActiveRecord::Base

  default_scope -> { where(destroyed_at: nil) }

  belongs_to :authorization
  belongs_to :todolist, class_name: "TodoList"
  belongs_to :created_by, class_name: "User"
  belongs_to :completed_by, class_name: "User"
  belongs_to :assigned_to, class_name: "User"

  before_save :associate_users_with_self

  class << self
    def sync(expected_items)
      Houston.benchmark("[todolist:sync:items] #{expected_items.length}") do
        expected_ids = expected_items.map { |item| item[:remote_id] }
        existing_ids = with_destroyed.pluck(:remote_id)

        with_destroyed.where(remote_id: existing_ids & expected_ids).each do |existing_item|
          attributes = expected_items.find { |item| item[:remote_id] == existing_item.remote_id }
          existing_item.update_attributes!(attributes)
        end

        expected_items.each do |attributes|
          next if existing_ids.member? attributes[:remote_id]
          next if attributes[:destroyed]
          unless (item = create(attributes)).persisted?
            Rails.logger.debug("[todolist:sync:items] item #{attributes.inspect} could not be created:\n#{item.errors.full_messages.join("\n")}")
          end
        end
      end
    end

    def with_destroyed
      unscope(where: :destroyed_at)
    end

    def completed
      where.not(completed_at: nil)
    end
  end

  def destroyed?
    destroyed_at.present?
  end

  def destroyed=(value)
    return if value == destroyed?
    self.destroyed_at = value ? Time.now : nil
  end

private

  def associate_users_with_self
    self.created_by = User.find_by_email_address(created_by_email) if created_by_email_changed?
    self.completed_by = User.find_by_email_address(completed_by_email) if completed_by_email_changed?
    self.assigned_to = User.find_by_email_address(assigned_to_email) if assigned_to_email_changed?
  end

end
