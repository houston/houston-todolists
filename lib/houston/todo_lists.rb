require "houston/todo_lists/engine"
require "houston/todo_lists/configuration"

module Houston
  module TodoLists
    extend self

    def config(&block)
      @configuration ||= TodoLists::Configuration.new
      @configuration.instance_eval(&block) if block_given?
      @configuration
    end

  end


  # Extension Points
  # ===========================================================================
  #
  # Read more about extending Houston at:
  # https://github.com/houston/houston-core/wiki/Modules

  oauth.add_provider :todoist do
    site "https://todoist.com"
    authorize_path "/oauth/authorize"
    token_path "/oauth/access_token"
  end

end
