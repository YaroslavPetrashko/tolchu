require "spec_helper"
require "open3"
require "rbconfig"

RSpec.describe "Test environment safety" do
  def run_helper(path, environment)
    script = <<~'RUBY'
      module SimpleCov
        def self.command_name(name)
          puts "coverage:#{name}"
        end

        def self.start(profile)
          puts "coverage_start:#{profile}"
        end
      end

      # Intercept every dependency load; stop before either entry point can boot Rails.
      module Kernel
        def require(path)
          return true if %w[simplecov spec_helper].include?(path)
          abort "Unexpected require: #{path}" unless path == "cucumber/rails"

          puts "boot:#{ENV.fetch('RAILS_ENV', 'unset')}"
          exit 0
        end

        def require_relative(path)
          abort "Unexpected require_relative: #{path}" unless path == "../config/environment"

          puts "boot:#{ENV.fetch('RAILS_ENV', 'unset')}"
          exit 0
        end
      end

      load ARGV.fetch(0)
      abort "Helper did not reach its Rails boot boundary"
    RUBY

    Open3.capture3(
      { "RAILS_ENV" => environment, "RUBYOPT" => nil, "RUBYLIB" => nil },
      RbConfig.ruby, "--disable-gems", "-e", script, File.expand_path(path, __dir__)
    )
  end

  { "rails_helper.rb" => "RSpec", "../features/support/env.rb" => "Cucumber" }.each do |path, suite|
    context suite do
      %w[development production staging].push("").each do |environment|
        it "rejects #{environment.inspect} before starting coverage or booting Rails" do
          out, err, status = run_helper(path, environment)

          expect(status.exitstatus).to eq(1)
          expect(out).to be_empty
          expect(err).to include("RAILS_ENV=test", environment.inspect)
        end
      end

      [ nil, "test" ].each do |environment|
        it "allows #{environment.inspect} and starts coverage before Rails" do
          out, err, status = run_helper(path, environment)

          expect(status).to be_success
          expect(err).to be_empty
          expect(out.lines.map(&:chomp)).to eq([ "coverage:#{suite}", "coverage_start:rails", "boot:test" ])
        end
      end
    end
  end
end
