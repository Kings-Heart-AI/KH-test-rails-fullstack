# activerecord 4.2.2's PostgreSQL adapter temporarily sets
# `client_min_messages = 'panic'` while running schema-altering
# statements, to silence notices. Modern PostgreSQL only accepts
# DEBUG5..ERROR for this session setting (FATAL/PANIC are valid for
# log_min_messages, not client_min_messages), so this raises
# PG::InvalidParameterValue on every migration. Clamp it to 'error',
# the strictest level Postgres actually accepts here.
if Rails.env.production?
  require 'active_record/connection_adapters/postgresql_adapter'
  module ActiveRecord::ConnectionAdapters::PostgreSQL::SchemaStatements
    def client_min_messages=(level)
      level = 'error' if level.to_s.downcase == 'panic'
      execute("SET client_min_messages TO '#{level}'", 'SCHEMA')
    end
  end
end
