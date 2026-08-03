ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

require 'bundler/setup' # Set up gems listed in the Gemfile.

# Ruby >= 2.7 removed BigDecimal.new, which activesupport 4.2.2 calls at
# load time (core_ext/object/duplicable.rb). Restore it so `rails/all`
# can load under newer Ruby versions used to run this app's test suite.
require 'bigdecimal'
class BigDecimal
  def self.new(*args)
    BigDecimal(*args)
  end
end

# Ruby's uri library dropped the @@schemes class variable in favor of
# URI.register_scheme, but globalid 0.4.2 (pulled in by activejob 4.2.2)
# still writes to it directly at load time. It's otherwise unused here
# (this app addresses URI::GID explicitly, never through generic scheme
# dispatch), so just give it an empty Hash to write into.
require 'uri'
URI.class_variable_set(:@@schemes, {}) unless URI.class_variable_defined?(:@@schemes)

# Since Ruby 2.4, Fixnum/Bignum are both just aliases for Integer. That
# breaks activesupport 4.2.2's core_ext/numeric/conversions.rb, which
# does `[Float, Fixnum, Bignum, BigDecimal].each { |klass| klass.send
# (:alias_method, :to_default_s, :to_s); klass.send(:define_method,
# :to_s) { ... to_default_s(*args) ... } }`: patching Integer a second
# time (once as "Fixnum", once as "Bignum") re-aliases :to_default_s to
# the *already-patched* :to_s from the first pass, so the fallback
# branch of the second :to_s recurses into itself forever (e.g. via
# `object_id.to_s(16)` in Rails' local_cache middleware). Capture the
# real, original #to_s here (before that file loads) so application.rb
# can repair :to_default_s afterwards.
ORIGINAL_NUMERIC_TO_S = {
  Integer => Integer.instance_method(:to_s),
  Float   => Float.instance_method(:to_s),
  BigDecimal => BigDecimal.instance_method(:to_s)
}

# Psych 4 (default on Ruby >= 3.1) made YAML.load behave like the old
# safe_load, which rejects the `<<: *default` merge-key alias used in
# config/database.yml ("Unknown alias: default"). Rails 4.2.2's
# `database_configuration` calls plain `YAML.load` on that file's
# contents. Fix only that one call site (via `YAML.unsafe_load`)
# instead of aliasing `YAML.load` itself process-wide, so every other
# YAML.load call in the app and its gems keeps Psych 4's safer, alias-
# rejecting default.
#
# `database_configuration` runs synchronously the moment `active_record
# /base` loads (via its `ActiveSupport.run_load_hooks(:active_record)`
# call), which happens partway through `require 'rails/all'` in
# config/application.rb -- before this app's own code gets a chance to
# patch anything post-load. So pre-require just 'rails' (the first line
# of rails/all.rb; requiring it again there is a no-op) here, early
# enough to patch Rails::Application::Configuration#database_configuration
# before active_record's railtie ever calls it.
require 'rails'
Rails::Application::Configuration.class_eval do
  def database_configuration
    path = paths["config/database"].existent.first
    yaml = Pathname.new(path) if path

    config = if yaml && yaml.exist?
      require "yaml"
      require "erb"
      YAML.unsafe_load(ERB.new(yaml.read).result) || {}
    elsif ENV['DATABASE_URL']
      {}
    else
      raise "Could not load database configuration. No such file - #{paths["config/database"].instance_variable_get(:@paths)}"
    end

    config
  rescue Psych::SyntaxError => e
    raise "YAML syntax error occurred while parsing #{paths["config/database"].first}. " \
          "Please note that YAML must be consistently indented using spaces. Tabs are not allowed. " \
          "Error: #{e.message}"
  rescue => e
    raise e, "Cannot load `Rails.application.database_configuration`:\n#{e.message}", e.backtrace
  end
end

# activerecord 4.2.2's sqlite3_adapter.rb hardcodes `gem 'sqlite3', '~>
# 1.3.6'` (a RubyGems version guard, independent of Bundler/the
# Gemfile), which rejects the sqlite3 1.4.4 this app now uses -- 1.3.x
# doesn't build on modern Ruby (its native ext calls the removed
# `rb_check_safe_obj`). Bundler already resolved/activated the exact
# locked sqlite3 version, so this legacy self-check is redundant; make
# it a no-op for sqlite3 only.
module Kernel
  alias_method :__pre_sqlite3_shim_gem, :gem
  def gem(name, *requirements)
    return true if name == 'sqlite3'
    __pre_sqlite3_shim_gem(name, *requirements)
  end
end

# activesupport 4.2.2 (and sdoc, doc-group only) pin `json` to the 1.x
# line, so Bundler resolves json 1.8.6. Its C extension's initializer
# uses an `rb_scan_args` format string ("1:") for the old
# hash-or-kwargs convention that Ruby's post-3.0 keyword-argument
# separation no longer satisfies the way this gem expects, so
# `JSON.parse(source, opts)` -- used e.g. to decode the encrypted
# session cookie on every request -- raises "wrong number of arguments
# (given 2, expected 1)". json 1.8.6 ships a pure-Ruby fallback with no
# such issue; force it instead of the (default, but broken here) C ext.
require 'json'
require 'json/pure'
JSON.parser = JSON::Pure::Parser
JSON.generator = JSON::Pure::Generator
