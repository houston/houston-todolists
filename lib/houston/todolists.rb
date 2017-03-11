require "houston/todolists/engine"
require "houston/todolists/configuration"

module Houston
  module Todolists
    extend self

    def config(&block)
      @configuration ||= Todolists::Configuration.new
      @configuration.instance_eval(&block) if block_given?
      @configuration
    end

  end


  # Extension Points
  # ===========================================================================
  #
  # Read more about extending Houston at:
  # https://github.com/houston/houston-core/wiki/Modules


  # Register events that will be raised by this module
  #
  #    register_events {{
  #      "todolists:create" => params("todolists").desc("Todolists was created"),
  #      "todolists:update" => params("todolists").desc("Todolists was updated")
  #    }}


  # Add a link to Houston's global navigation
  #
  #    add_navigation_renderer :todolists do
  #      name "Todolists"
  #      path { Houston::Todolists::Engine.routes.url_helpers.todolists_path }
  #      ability { |ability| ability.can? :read, Project }
  #    end


  # Add a link to feature that can be turned on for projects
  #
  #    add_project_feature :todolists do
  #      name "Todolists"
  #      path { |project| Houston::Todolists::Engine.routes.url_helpers.project_todolists_path(project) }
  #      ability { |ability, project| ability.can? :read, project }
  #    end

end
