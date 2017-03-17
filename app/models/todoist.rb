class Todoist < Authorization
  has_many :todolists, class_name: "TodoList", inverse_of: :authorization, foreign_key: "authorization_id"
  has_many :todolist_items, class_name: "TodoListItem", inverse_of: :authorization, foreign_key: "authorization_id"

  def self.sync!
    all.each(&:sync!)
  end

  def sync!
    response = connection.post("sync",
      token: access_token,
      sync_token: sync_token,
      resource_types: MultiJson.dump(%w{projects items collaborators}))
    data = MultiJson.load(response.body)

    completed_items = []
    completed_projects = []
    if data["full_sync"]
      Houston.benchmark "[todoist] Fetching completed items" do
        offset = 0
        limit = 50
        requests = 0
        params = { token: access_token, limit: limit }
        last_completed = todolist_items.completed.order(completed_at: :desc).first
        params[:since] = last_completed.completed_at if last_completed
        loop do
          response = connection.post("completed/get_all", params.merge(offset: offset))
          data2 = MultiJson.load(response.body)
          requests += 1
          offset += limit
          completed_items.concat data2["items"]
          completed_projects.concat data2["projects"].values
          break if data2["items"].length < limit
        end

        Rails.logger.info "[todoist] #{requests} requests"
      end
    end

    collaborators = data.fetch "collaborators"
    projects = data.fetch "projects"
    items = data.fetch "items"

    items_by_id = items.index_by { |item| item["id"] }
    completed_items.each do |completed_item|
      item = items_by_id[completed_item["id"]]
      if item
        item["completed_date"] = completed_item["completed_date"]
      else
        items_by_id[completed_item["id"]] = completed_item
      end
    end
    items = items_by_id.values

    projects_by_id = projects.index_by { |project| project["id"] }
    completed_projects.each do |completed_project|
      unless projects_by_id.key?(completed_project["id"])
        projects_by_id[completed_project["id"]] = completed_project
      end
    end
    projects = projects_by_id.values

    transaction do
      update_prop! SYNC_TOKEN, data["sync_token"]

      collaborators.each do |collaborator|
        user = User.find_by_email_address collaborator["email"]
        if user
          user.update_prop! USER_ID, collaborator["id"]
        else
          Rails.logger.info "[todoist.sync!] Found no user with email address #{collaborator["email"]}"
        end
      end

      todolists.sync(projects.map { |project|
        { remote_id: project["id"].to_s,
          name: project["name"],
          destroyed: project["is_deleted"] == 1 || project["is_archived"] == 1 } })
          # props: { color: TODOIST_COLORS[project["color"]] } })

      list_map = Hash[todolists.pluck(:remote_id, :id)]
      user_map = Hash[User.with_prop(USER_ID).pluck("props->>'#{USER_ID}'", :id)]

      # Ignore items that don't belong to projects for now.
      items.reject! { |item| item["project_id"].zero? }

      todolist_items.sync(items.map do |item|
        { remote_id: item["id"].to_s,
          summary: item["content"],
          todolist_id: list_map.fetch(item["project_id"].to_s),
          created_by_id: user_map[item["user_id"]],
          assigned_to_id: user_map[item["responsible_uid"]],
          destroyed: item["is_deleted"] == 1 || item["is_archived"] == 1 }.tap do |attrs|
          if item.key?("completed_date")
            attrs[:completed_at] = Time.parse(item["completed_date"])
          end
          if item.key?("date_added")
            attrs[:created_at] = Time.parse(item["date_added"])
          end
        end
      end)
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
  FULL_SYNC = "*".freeze
  USER_ID = "todoist.userID".freeze
  # TODOIST_COLORS = [
  #   "rgb(149, 239, 99)",
  #   "rgb(255, 133, 129)",
  #   "rgb(255, 196, 113)",
  #   "rgb(249, 236, 117)",
  #   "rgb(168, 200, 228)",
  #   "rgb(210, 184, 163)",
  #   "rgb(226, 168, 228)",
  #   "rgb(204, 204, 204)",
  #   "rgb(251, 136, 110)",
  #   "rgb(255, 204, 0)",
  #   "rgb(116, 232, 211)",
  #   "rgb(59, 213, 251)",
  #   "rgb(220, 79, 173)",
  #   "rgb(172, 25, 61)",
  #   "rgb(210, 71, 38)",
  #   "rgb(130, 186, 0)",
  #   "rgb(3, 179, 178)",
  #   "rgb(0, 130, 153)",
  #   "rgb(93, 178, 255)",
  #   "rgb(0, 114, 198)",
  #   "rgb(0, 0, 0)",
  #   "rgb(119, 119, 119)"
  # ].freeze

end
