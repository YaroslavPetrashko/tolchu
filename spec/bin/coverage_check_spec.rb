require "rails_helper"
require "open3"
require "tempfile"

# Runs the real script against a report we write ourselves, never the one this suite is producing.
RSpec.describe "bin/coverage-check" do
  def report(lines:, branches: 91.8, suites: %w[Cucumber RSpec])
    { meta: { command_names: suites }, total: { lines: { percent: lines }, branches: { percent: branches } } }.to_json
  end

  def check(json, env = {})
    Tempfile.create([ "coverage", ".json" ]) do |file|
      file.write(json)
      file.flush
      Open3.capture3(env.merge("COVERAGE_REPORT" => file.path), Rails.root.join("bin/coverage-check").to_s)
    end
  end

  it "passes at or above 90% and prints both percentages" do
    out, _err, status = check(report(lines: 90.0))

    expect(status).to be_success
    expect(out).to eq("Line coverage 90.0% (minimum 90.0%), branch coverage 91.8%\n")
  end

  it "fails just below the minimum, without rounding up" do
    _out, err, status = check(report(lines: 89.999))

    expect(status).not_to be_success
    expect(err).to eq("Line coverage 89.99% is below 90.0%\n")
  end

  it "doesn't gate branch coverage" do
    _out, _err, status = check(report(lines: 95.0, branches: 40.0))

    expect(status).to be_success
  end

  it "honours MIN_LINE_COVERAGE" do
    expect(check(report(lines: 97.8), "MIN_LINE_COVERAGE" => "100").last).not_to be_success
    expect(check(report(lines: 80.0), "MIN_LINE_COVERAGE" => "75").last).to be_success
  end

  it "refuses a report that only contains one suite" do
    _out, err, status = check(report(lines: 99.0, suites: %w[RSpec]))

    expect(status).not_to be_success
    expect(err).to include('only has ["RSpec"]', "run RSpec and Cucumber first")
  end

  it "fails with a clear message when there is no report" do
    _out, err, status = Open3.capture3({ "COVERAGE_REPORT" => "/nonexistent/coverage.json" }, Rails.root.join("bin/coverage-check").to_s)

    expect(status).not_to be_success
    expect(err).to include("No coverage report at /nonexistent/coverage.json")
  end

  it "appends a table to the GitHub job summary when one is available" do
    Tempfile.create("summary") do |summary|
      check(report(lines: 97.8), "GITHUB_STEP_SUMMARY" => summary.path)

      expect(File.read(summary.path)).to include("### Merged coverage", "| 97.8% | 91.8% |")
    end
  end
end
