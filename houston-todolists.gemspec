$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "houston/todo_lists/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name          = "houston-todolists"
  spec.version       = Houston::TodoLists::VERSION
  spec.authors       = ["Bob Lail"]
  spec.email         = ["bob.lailfamily@gmail.com"]

  spec.summary       = "Allows you to sync to-do lists with Todoist"
  spec.homepage      = "https://github.com/houston/houston-todolists"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.require_paths = ["lib"]
  spec.test_files = Dir["test/**/*"]

  spec.add_dependency "houston-core", ">= 0.9.0-dev"

  spec.add_development_dependency "bundler", "~> 1.14.6"
  spec.add_development_dependency "rake", "~> 10.0"
end
