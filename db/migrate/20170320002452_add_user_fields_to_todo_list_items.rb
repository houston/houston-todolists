class AddUserFieldsToTodoListItems < ActiveRecord::Migration[5.0]
  def change
    add_belongs_to :todo_list_items, :completed_by, foreign_key: { to_table: :users, on_delete: :nullify }

    add_column :todo_list_items, :created_by_email, :string
    add_column :todo_list_items, :assigned_to_email, :string
    add_column :todo_list_items, :completed_by_email, :string
  end
end
