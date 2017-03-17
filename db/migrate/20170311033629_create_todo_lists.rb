class CreateTodoLists < ActiveRecord::Migration[5.0]
  def change
    create_table :todo_lists do |t|
      t.belongs_to :authorization, foreign_key: { on_delete: :nullify }, index: true
      t.string :remote_id, null: false, index: true

      t.string :name, null: false
      t.integer :sequence, null: false, default: 0
      t.jsonb :props, null: false, default: {}

      t.timestamp :destroyed_at
      t.timestamps
    end

    create_table :todo_list_items do |t|
      t.belongs_to :authorization, foreign_key: { on_delete: :nullify }, index: true
      t.belongs_to :todolist, foreign_key: { to_table: :todo_lists, on_delete: :cascade }, index: true
      t.belongs_to :created_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.belongs_to :assigned_to, foreign_key: { to_table: :users, on_delete: :nullify }

      t.string :remote_id, null: false, index: true
      t.string :summary, null: false
      t.jsonb :props, null: false, default: {}

      t.timestamp :destroyed_at
      t.timestamp :completed_at
      t.timestamps
    end
  end
end
