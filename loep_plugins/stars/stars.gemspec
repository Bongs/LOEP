$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "stars/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "stars"
  s.version     = Stars::VERSION
  s.authors     = ["TODO: Your name"]
  s.email       = ["TODO: Your email"]
  s.homepage    = "TODO"
  s.summary     = "TODO: Summary of Stars."
  s.description = "TODO: Description of Stars."

  s.files = Dir["{app,config,db,lib}/**/*"] + ["Rakefile"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 3.2.22"
  # s.add_dependency "jquery-rails"

  s.add_development_dependency "sqlite3"
end
