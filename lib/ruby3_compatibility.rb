# Rails 4.2.2 / associated gems predate Ruby 3, which removed several
# APIs they rely on. This file repairs those spots so the app (and its
# test suite) can run on the Ruby version available in this environment.
# Load after `require 'rails/all'`, once the classes below exist.

# 1) Fixnum/Bignum both alias Integer since Ruby 2.4, so activesupport's
#    `[Float, Fixnum, Bignum, BigDecimal].each { |klass| ... }` in
#    active_support/core_ext/numeric/conversions.rb patches Integer
#    twice, corrupting its #to_s (infinite recursion, e.g. via
#    `object_id.to_s(16)` in Rails' local_cache middleware).
#    ORIGINAL_NUMERIC_TO_S is captured in config/boot.rb, before that
#    file loads, so it holds the real, unpatched #to_s.
require 'active_support/core_ext/numeric/conversions'
ORIGINAL_NUMERIC_TO_S.each do |klass, method|
  klass.send(:define_method, :to_default_s, method)
end

# 2) Ruby 3.0 removed implicit block capture via a bare `Proc.new`
#    (previously deprecated in 2.7); it now always raises ArgumentError,
#    even when the enclosing method genuinely received a block. Several
#    Rails 4.2.2 methods use `def foo(bar = Proc.new)` / `Proc.new if
#    block_given?` to capture an optional trailing block that way.
#    Redefine each with an explicit `&block` parameter instead,
#    otherwise behaviorally identical to the original.
module ActiveSupport
  module Notifications
    class Fanout
      # The original also accepts a subscriber object as a plain
      # positional 2nd argument (see e.g. `subscribe('name',
      # ActionController::PageRequest.new)` in this file's docs), not
      # just a block, so accept both.
      def subscribe(pattern = nil, callable = nil, &block)
        subscriber = Subscribers.new pattern, (callable || block)
        synchronize do
          @subscribers << subscriber
          @listeners_for.clear
        end
        subscriber
      end
    end
  end
end

class ActiveRecord::StatementCache
  def self.create(connection, &block)
    relation      = block.call Params.new
    bind_map      = BindMap.new relation.bind_values
    query_builder = connection.cacheable_query relation.arel
    new query_builder, bind_map
  end
end

require 'action_controller/metal'
ActionController::MiddlewareStack.class_eval do
  def build(action, &app)
    action = action.to_s

    middlewares.reverse.inject(app) do |a, middleware|
      middleware.valid?(action) ? middleware.build(a) : a
    end
  end
end

# 3) actionpack 4.2.2's EncryptedCookieJar derives its AES-256-CBC key
#    via `key_generator.generate_key(salt)`, which defaults to a
#    64-byte key -- always too long for a 32-byte AES-256 key. Older
#    OpenSSL bindings silently truncated an oversized key; the OpenSSL
#    gem bundled with this Ruby enforces the exact length and raises
#    ArgumentError ("key must be 32 bytes"), breaking every encrypted
#    session cookie (e.g. `log_in_as` in integration tests). Request the
#    correct length explicitly, matching the actual Rails fix shipped in
#    later 4.2.x patch releases.
require 'action_dispatch/middleware/cookies'
ActionDispatch::Cookies::EncryptedCookieJar.class_eval do
  def initialize(parent_jar, key_generator, options = {})
    if ActiveSupport::LegacyKeyGenerator === key_generator
      raise "You didn't set secrets.secret_key_base, which is required for this cookie jar. " +
        "Read the upgrade documentation to learn more about this new config option."
    end

    @parent_jar = parent_jar
    @options = options
    key_len = ActiveSupport::MessageEncryptor.key_len(@options[:cipher] || 'aes-256-cbc')
    secret = key_generator.generate_key(@options[:encrypted_cookie_salt], key_len)
    sign_secret = key_generator.generate_key(@options[:encrypted_signed_cookie_salt])
    @encryptor = ActiveSupport::MessageEncryptor.new(secret, sign_secret, digest: digest, serializer: ActiveSupport::MessageEncryptor::NullSerializer)
  end
end

module ActiveSupport
  class MessageEncryptor
    def self.key_len(cipher = 'aes-256-cbc')
      OpenSSL::Cipher.new(cipher).key_len
    end
  end
end

ActiveRecord::Scoping::Default::ClassMethods.class_eval do
  def default_scope(scope = nil, &block)
    scope = block if block_given?

    if scope.is_a?(ActiveRecord::Relation) || !scope.respond_to?(:call)
      raise ArgumentError,
        "Support for calling #default_scope without a block is removed. For example instead " \
        "of `default_scope where(color: 'red')`, please use " \
        "`default_scope { where(color: 'red') }`. (Alternatively you can just redefine " \
        "self.default_scope.)"
    end

    self.default_scopes += [scope]
  end
end

# 5) ActionController::TestCase reuses one TestResponse instance across
#    requests within a test, calling `#recycle!` -> `initialize` again
#    on the *same* object to reset it. `ActionDispatch::Response`
#    includes MonitorMixin, so that re-runs MonitorMixin's own
#    `initialize` too; Ruby's monitor.rb (>= 3.0) raises ThreadError
#    ("already initialized") on a second call for the same object,
#    where it used to just silently rebuild the mutex. Clear the
#    MonitorMixin bookkeeping ivars first so re-initializing is legal.
require 'action_controller/test_case'
[ActionController::TestResponse, ActionController::LiveTestResponse].each do |klass|
  klass.class_eval do
    def recycle!
      remove_instance_variable(:@mon_data) if defined?(@mon_data)
      remove_instance_variable(:@mon_data_owner_object_id) if defined?(@mon_data_owner_object_id)
      @body = nil if self.is_a?(ActionController::LiveTestResponse)
      initialize
    end
  end
end
