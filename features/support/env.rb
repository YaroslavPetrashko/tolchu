ENV["RAILS_ENV"] ||= "test"
abort "Tests require RAILS_ENV=test (got #{ENV['RAILS_ENV'].inspect})" unless ENV["RAILS_ENV"] == "test"

require "simplecov"
SimpleCov.command_name "Cucumber"
SimpleCov.start "rails"

require 'cucumber/rails'

ActionController::Base.allow_rescue = false

begin
  DatabaseCleaner.strategy = :transaction
rescue NameError
  raise "You need to add database_cleaner to your Gemfile (in the :test group) if you wish to use it."
end

Cucumber::Rails::Database.javascript_strategy = :truncation
