class TodoListItem < ActiveRecord::Base

  belongs_to :authorization
  belongs_to :todolist, class_name: "TodoList"
  belongs_to :created_by, class_name: "User"
  belongs_to :assigned_to, class_name: "User"

  class << self
    def sync(expected_items)
      Houston.benchmark("[todolist:sync:items] #{expected_items.length}") do
        expected_ids = expected_items.map { |item| item[:remote_id] }
        existing_ids = pluck(:remote_id)

        where(remote_id: existing_ids - expected_ids).delete_all

        where(remote_id: existing_ids & expected_ids).each do |existing_item|
          attributes = expected_items.find { |item| item[:remote_id] == existing_item.remote_id }
          existing_item.update_attributes!(attributes)
        end

        expected_items.each do |attributes|
          next if existing_ids.member? attributes[:remote_id]
          create!(attributes)
        end
      end
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

  def completed?
    completed_at.present?
  end

  def completed=(value)
    return if value == completed?
    self.completed_at = value ? Time.now : nil
  end

end
