module Houston::TodoLists
  class TodoistController < ::ApplicationController
    before_action :authenticate_user!
    layout "houston/todolists/application"

    def auth
      oauth_authorize! Todoist, scope: "data:read_write", redirect_to: request.referer
    end

    def webhook
      # TODO: make this smarter, only sync accounts for the current user...
      Todoist.sync!
    end

  end
end
