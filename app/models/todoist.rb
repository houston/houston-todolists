class Todoist < Authorization

  has_many :todolists, class_name: "TodoList", inverse_of: :authorization, foreign_key: "authorization_id"
  has_many :todolist_items, class_name: "TodoListItem", inverse_of: :authorization, foreign_key: "authorization_id"



  def self.sync!
    all.each(&:sync!)
  end

  def sync!
    Houston.benchmark "[todoist] sync" do
      data = sync


      projects = data.fetch "projects"
      items = data.fetch "items"
      email_by_user_id = Hash[data.fetch("collaborators").map { |user| user.values_at("id", "email") }]
      projects_by_id = projects.index_by { |project| project["id"] }
      items_by_id = items.index_by { |item| item["id"] }
      items_by_id.default_proc = proc do |index, id|
        item_data = get_item(id)
        next unless item_data
        index[id] = item_data.fetch("item").tap do
          project = item_data.fetch("project")
          project_id = project.fetch("id")
          projects_by_id[project_id] = project unless projects_by_id.key?(project_id)
        end
      end


      max_completed_at = nil
      recently_completed_items.each do |completed_item|
        id = completed_item.fetch("object_id")
        initiator_id = completed_item.fetch("initiator_id")
        completed_at = Time.parse(completed_item["event_date"])
        max_completed_at = completed_at unless max_completed_at && max_completed_at > completed_at
        email = email_by_user_id.fetch(initiator_id, nil)

        item = items_by_id[id]
        if item && item["checked"] == 1
          item["completed_at"] = completed_at
          item["completed_by_email"] = email
        else
          Rails.logger.debug "[todoist] item #{id} was completed by #{initiator_id} (#{email}) at #{completed_at} but isn't visible to #{user.name}"
        end
      end
      items = items_by_id.values
      projects = projects_by_id.values


      transaction do
        update_prop! SYNC_TOKEN, data["sync_token"]
        update_prop! SYNC_SINCE, max_completed_at if max_completed_at


        todolists.sync(projects.map do |project|
          expected = { remote_id: project["id"].to_s }

          # When Todoist returns a project or item that's deleted,
          # several of the value are erased. We don't want to overwrite
          # those.
          next expected.merge(destroyed: true) if project["is_deleted"] == 1

          expected.merge(
            name: project["name"],
            archived: project["is_archived"] == 1)
        end)
        list_map = Hash[todolists.with_destroyed.pluck(:remote_id, :id)]


        items = items.find_all do |item|
          next true if list_map.key? item["project_id"].to_s
          Rails.logger.debug "[todoist] item #{item["id"]} won't be synced because its project #{item["project_id"]} hasn't been synced"
          false
        end


        todolist_items.sync(items.map do |item|
          expected = { remote_id: item["id"].to_s }

          # When Todoist returns a project or item that's deleted,
          # several of the value are erased. We don't want to overwrite
          # those.
          #
          # Don't differentiate between archived items and deleted items.
          next expected.merge(destroyed: true) if item["is_deleted"] == 1 || item["is_archived"] == 1

          if item["checked"] == 1 && !item["completed_at"]
            Rails.logger.debug "[todoist] item #{item["id"]} was completed, but the activity log didn't have a record of that"
            item["completed_at"] = Time.now
          end

          expected.merge(
            destroyed: false,
            summary: item["content"],
            todolist_id: list_map.fetch(item["project_id"].to_s),
            created_at: Time.parse(item["date_added"]),
            created_by_email: email_by_user_id[item["user_id"]],
            assigned_to_email: email_by_user_id[item["responsible_uid"]],
            completed_at: item["completed_at"],
            completed_by_email: item["completed_by_email"])
        end)
      end
    end

    self
  end



  def synced?
    sync_token != FULL_SYNC
  end

  def sync_token
    props.fetch(SYNC_TOKEN, FULL_SYNC)
  end

  def connection
    @connection ||= Faraday.new(url: "https://todoist.com/API/v7").tap do |connection|
      connection.use Faraday::RaiseErrors
    end
  end



  SYNC_TOKEN = "todoist.syncToken".freeze
  SYNC_SINCE = "todoist.since".freeze
  FULL_SYNC = "*".freeze

private

  def sync
    Houston.benchmark "[todoist] POST /sync" do
      response = connection.post("sync",
        token: access_token,
        sync_token: sync_token,
        resource_types: MultiJson.dump(%w{projects items collaborators}))
      MultiJson.load(response.body)
    end
  end

  def recently_completed_items
    completed_since props[SYNC_SINCE]
  end

  def completed_since(timestamp)
    all_events = []
    Houston.benchmark "[todoist] POST /activity/get" do
      offset = 0
      limit = 100
      params = { object_event_types: '["item:completed"]', token: access_token, limit: limit }
      params[:since] = timestamp if timestamp
      loop do
        response = connection.post("activity/get", params.merge(offset: offset))
        events = MultiJson.load(response.body)
        offset += limit
        all_events.concat events
        break if events.length < limit
      end
      Rails.logger.info "\e[33m[todoist] \e[1m#{(offset / limit) + 1}\e[0;33m requests\e[0m"
    end
    all_events
  end

  def get_item(id)
    Houston.benchmark "[todoist] POST /items/get #{id}" do
      begin
        response = connection.post("items/get", token: access_token, item_id: id)
        MultiJson.load(response.body)
      rescue Faraday::ResourceNotFound
        nil
      end
    end
  end

end
