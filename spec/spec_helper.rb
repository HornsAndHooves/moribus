ENV["RAILS_ENV"] ||= 'test'

unless ENV['CI']
  require "simplecov"

  SimpleCov.start do
    # Fail the build when coverage is weak:
    at_exit do
      SimpleCov.result.format!
      threshold, actual = 100, SimpleCov.result.covered_percent
      if actual < threshold
        msg = "\nLow coverage: "
        msg << red("#{actual}%")
        msg << " is #{red 'under'} the threshold: "
        msg << green("#{threshold}%.")
        msg << "\n"
        $stderr.puts msg
        exit 1
      else
        # Precision: three decimal places:
        actual_trunc = (actual * 1000).floor / 1000.0
        msg = "\nCoverage: "
        msg << green("#{actual}%")
        msg << " is #{green 'over'} the threshold: "
        if actual_trunc > threshold
          msg << bold(yellow("#{threshold}%. "))
          msg << "Please update the threshold to: "
          msg << bold(green("#{actual_trunc}% "))
          msg << "in ./.simplecov."
        else
          msg << green("#{threshold}%.")
        end
        msg << "\n"
        $stdout.puts msg
      end
    end
  end
end

require File.expand_path("../../spec/dummy/config/environment", __FILE__)
require "rspec/rails"
require "moribus"

Dir["./spec/support/**/*.rb"].sort.each { |f| require f }

RSpec.configure do |config|
  config.mock_with :rspec
  config.use_transactional_fixtures = true
end
