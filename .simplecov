require "simplecov-rcov-text"
require "colorized_text"
include ColorizedText

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
  SimpleCov::Formatter::RcovTextFormatter,
  SimpleCov::Formatter::HTMLFormatter
])
SimpleCov.skip "/spec/"
