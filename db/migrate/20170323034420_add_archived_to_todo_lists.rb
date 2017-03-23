class AddArchivedToTodoLists < ActiveRecord::Migration[5.0]
  def change
    add_column :todo_lists, :archived, :boolean, null: false, default: false
  end
end
