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
# `database_configuration` calls plain `YAML.load`, so restore the old,
# alias-permissive behavior.
require 'yaml'
YAML.singleton_class.send(:alias_method, :load, :unsafe_load) if YAML.respond_to?(:unsafe_load)

# activerecord 4.2.2's sqlite3_adapter.rb hardcodes `gem 'sqlite3', '~>
# 1.3.6'` (a RubyGems version guard, independent of Bundler/the
# Gemfile), which rejects the sqlite3 1.4.4 this app now uses -- 1.3.x
# doesn't build on modern Ruby (its native ext calls the removed
# `rb_check_safe_obj`). Likewise, activerecord's postgresql_adapter.rb
# hardcodes `gem 'pg', '~> 0.15'`, rejecting the pg 1.5.6 this app now
# uses (0.x doesn't build against modern libpq). Bundler already
# resolved/activated the exact locked version of each, so this legacy
# self-check is redundant; make it a no-op for these two gems only.
module Kernel
  alias_method :__pre_sqlite3_shim_gem, :gem
  def gem(name, *requirements)
    return true if %w[sqlite3 pg].include?(name)
    __pre_sqlite3_shim_gem(name, *requirements)
  end
end

# activerecord 4.2.2's postgresql_adapter.rb calls `PGconn.connect`, the
# name the pg gem's connection class used before 1.0. pg 1.5.6 (needed
# for this Ruby/deploy target, see production Gemfile group) no longer
# defines that backwards-compat alias. Restore it. The pg gem is only
# bundled in the :production group, so this is a no-op elsewhere.
# Same deal for `PGresult`, used elsewhere in the same adapter file to
# read error fields off a failed query.
begin
  require 'pg'
  PGconn   = PG::Connection unless defined?(PGconn)
  PGresult = PG::Result     unless defined?(PGresult)
rescue LoadError
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
