Houston::TodoLists::Engine.routes.draw do

  get "todoist/auth", to: "todoist#auth"
  get "hooks/todoist", to: "todoist#webhook"

end
