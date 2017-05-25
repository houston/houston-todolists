class CorrectFunctionForCachingTodoListCounts < ActiveRecord::Migration[5.0]
  def up
    execute <<~SQL
    CREATE OR REPLACE FUNCTION cache_items_count_on_todo_list()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
    BEGIN
      IF TG_OP IN ('DELETE', 'UPDATE') THEN
        UPDATE todo_lists SET
          items_count=(SELECT COUNT(*) FROM todo_list_items WHERE todo_list_items.todolist_id=todo_lists.id AND todo_list_items.destroyed_at IS NULL),
          completed_items_count=(SELECT COUNT(*) FROM todo_list_items WHERE todo_list_items.todolist_id=todo_lists.id AND todo_list_items.destroyed_at IS NULL AND todo_list_items.completed_at IS NOT NULL)
        WHERE id=OLD.todolist_id;
      END IF;

      IF TG_OP IN ('UPDATE', 'INSERT') THEN
        UPDATE todo_lists SET
          items_count=(SELECT COUNT(*) FROM todo_list_items WHERE todo_list_items.todolist_id=todo_lists.id AND todo_list_items.destroyed_at IS NULL),
          completed_items_count=(SELECT COUNT(*) FROM todo_list_items WHERE todo_list_items.todolist_id=todo_lists.id AND todo_list_items.destroyed_at IS NULL AND todo_list_items.completed_at IS NOT NULL)
        WHERE id=NEW.todolist_id;

        RETURN NEW;
      ELSE
        RETURN OLD;
      END IF;
    END;
    $$;
    SQL

    execute <<~SQL
      UPDATE todo_lists SET
        items_count=(SELECT COUNT(*) FROM todo_list_items WHERE todo_list_items.todolist_id=todo_lists.id AND todo_list_items.destroyed_at IS NULL),
        completed_items_count=(SELECT COUNT(*) FROM todo_list_items WHERE todo_list_items.todolist_id=todo_lists.id AND todo_list_items.destroyed_at IS NULL AND todo_list_items.completed_at IS NOT NULL);
    SQL
  end

  def down
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
  end
end
