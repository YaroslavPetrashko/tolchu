ENV["RAILS_ENV"] ||= "test"
abort "Tests require RAILS_ENV=test (got #{ENV['RAILS_ENV'].inspect})" unless ENV["RAILS_ENV"] == "test"

require "simplecov"
SimpleCov.command_name "RSpec"
SimpleCov.start "rails"

require "spec_helper"
require_relative "../config/environment"
require "rspec/rails"

Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |file| require file }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods
  config.include ActiveSupport::Testing::TimeHelpers
  config.include AuthenticationHelpers, type: :request
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
