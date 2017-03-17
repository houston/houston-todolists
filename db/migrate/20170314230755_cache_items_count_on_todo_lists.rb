class CacheItemsCountOnTodoLists < ActiveRecord::Migration[5.0]
  def up
    add_column :todo_lists, :items_count, :integer, null: false, default: 0
    add_column :todo_lists, :completed_items_count, :integer, null: false, default: 0

    execute <<~SQL
    CREATE OR REPLACE FUNCTION cache_items_count_on_todo_list()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
    BEGIN
      IF TG_OP IN ('DELETE', 'UPDATE') THEN
        UPDATE todo_lists SET
          items_count=(SELECT COUNT(*) FROM todo_list_items WHERE todo_list_items.todolist_id=todo_lists.id),
          completed_items_count=(SELECT COUNT(*) FROM todo_list_items WHERE todo_list_items.todolist_id=todo_lists.id AND todo_list_items.completed_at IS NOT NULL)
        WHERE id=OLD.todolist_id;
      END IF;

      IF TG_OP IN ('UPDATE', 'INSERT') THEN
        UPDATE todo_lists SET
          items_count=(SELECT COUNT(*) FROM todo_list_items WHERE todo_list_items.todolist_id=todo_lists.id),
          completed_items_count=(SELECT COUNT(*) FROM todo_list_items WHERE todo_list_items.todolist_id=todo_lists.id AND todo_list_items.completed_at IS NOT NULL)
        WHERE id=NEW.todolist_id;

        RETURN NEW;
      ELSE
        RETURN OLD;
      END IF;
    END;
    $$;
    SQL

    execute <<~SQL
      CREATE TRIGGER cache_items_count_on_todo_list_trigger
        AFTER INSERT OR DELETE OR UPDATE ON todo_list_items
        FOR EACH ROW EXECUTE PROCEDURE cache_items_count_on_todo_list();
    SQL

    execute <<~SQL
      UPDATE todo_lists SET
        items_count=(SELECT COUNT(*) FROM todo_list_items WHERE todo_list_items.todolist_id=todo_lists.id),
        completed_items_count=(SELECT COUNT(*) FROM todo_list_items WHERE todo_list_items.todolist_id=todo_lists.id AND todo_list_items.completed_at IS NOT NULL);
    SQL
  end

  def down
    execute "DROP FUNCTION IF EXISTS cache_items_count_on_todo_list() CASCADE"
    remove_column :todo_lists, :items_count
    remove_column :todo_lists, :completed_items_count
  end
end
