# frozen_string_literal: true

require "active_record_query_trace"

# Allows seeing the backtrace for queries
# Only use lines that pertain to ESM
ActiveRecordQueryTrace.level = :custom
ActiveRecordQueryTrace.backtrace_cleaner = lambda do |trace|
  trace.select { |line| line.match?("esm") }
end
ActiveRecordQueryTrace.enabled = ENV["TRACE"] == "true"

ESM.logger.level = Logger::TRACE

# Enable discordrb logging
Discordrb::LOGGER.debug = false

# ActiveRecord logging
ActiveRecord::Base.logger.level = Logger::INFO if ActiveRecord::Base.logger.present?
