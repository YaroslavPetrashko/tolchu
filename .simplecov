# Shared SimpleCov config for RSpec and Cucumber (each helper calls SimpleCov.start).
# Results from both suites merge into coverage/index.html when run back-to-back.
SimpleCov.configure do
  enable_coverage :branch
  skip %w[/bin/ /db/ /config/ /features/ /spec/ /vendor/ /lib/tasks/cucumber.rake]
  group "Services", "app/services"
  merge_timeout 3600
end
