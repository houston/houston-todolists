class TodoList < ActiveRecord::Base
  include Houston::Props

  belongs_to :authorization
  has_and_belongs_to_many :goals
  has_many :items, class_name: "TodoListItem"

  validates :name, :authorization_id, :remote_id, presence: true

  class << self
    def sync(expected_lists)
      Houston.benchmark("[todolist:sync:lists] #{expected_lists.length}") do
        expected_ids = expected_lists.map { |list| list[:remote_id] }
        existing_ids = pluck(:remote_id)

        where(remote_id: existing_ids & expected_ids).each do |existing_list|
          attributes = expected_lists.find { |list| list[:remote_id] == existing_list.remote_id }
          existing_list.update_attributes!(attributes)
        end

        expected_lists.each do |attributes|
          next if existing_ids.member? attributes[:remote_id]
          create!(attributes)
        end
      end
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
