require 'logger'

module ComposableAgents
  # Proxy around any Ruby-like logger that prefixes fields to the logged messages.
  # This is a standard ::Logger that inherits all the severity methods (debug, info, warn, error, fatal, unknown),
  #   but overrides the add/log methods to delegate the actual logging to the wrapped logger,
  #   with the given fields prefixed to the message.
  # Messages can be given as a String or a Proc returning the message (for lazy evaluation).
  class Logger::Tagged < ::Logger
    # Mapping of severity values to the corresponding severity methods on the wrapped logger
    SEVERITY_METHODS = {
      ::Logger::DEBUG => :debug,
      ::Logger::INFO => :info,
      ::Logger::WARN => :warn,
      ::Logger::ERROR => :error,
      ::Logger::FATAL => :fatal,
      ::Logger::UNKNOWN => :unknown
    }.freeze

    # @!group Public API

    # Constructor
    #
    # @param logger [Object] Any Ruby-like logger responding to the standard severity methods
    # @param fields [Array<String>] Fields to be prefixed to each logged message
    def initialize(logger, fields)
      @logger = logger
      @fields = fields
      # This proxy does not log on its own: the wrapped logger does. Its level is kept in sync so that
      #   the inherited level predicates (debug?, info?...) reflect the wrapped logger's level.
      super(nil, level: logger.respond_to?(:level) ? logger.level : ::Logger::DEBUG)
    end

    # Log a message with the given severity, delegating to the wrapped logger with the fields prefixed.
    # This is the implementation used by all severity methods, that all call #add in ::Logger.
    #
    # @param severity [Integer, nil] Severity of the message
    # @param message [String, #call => String, nil] Message string, Proc returning the message for lazy evaluation,
    #   or nil if the message is given by the progname or a block
    # @param progname [String, nil] Program name to be logged if the message is nil
    # @yield The optional code returning the message to log
    # @yieldreturn [String] The message to log
    # @return [Boolean] True, as ::Logger#add does
    def add(severity, message = nil, progname = nil, &)
      log_message(severity, message, progname, &)
    end

    # Log a message with the given severity.
    # Defined because ::Logger defines #log as an alias of #add, and aliases are bound at definition time:
    #   without redefining it here, #log would not use this class' #add override.
    #
    # @param severity [Integer, nil] Severity of the message
    # @param message [String, #call => String, nil] Message string, Proc returning the message for lazy evaluation,
    #   or nil if the message is given by the progname or a block
    # @param progname [String, nil] Program name to be logged if the message is nil
    # @yield The optional code returning the message to log
    # @yieldreturn [String] The message to log
    # @return [Boolean] True, as ::Logger#add does
    def log(severity, message = nil, progname = nil, &)
      add(severity, message, progname, &)
    end

    private

    # Delegate the message to the wrapped logger, with the fields prefixed.
    # The message is evaluated lazily (only when the wrapped logger's severity level allows it),
    #   by passing a block to the wrapped logger's severity method.
    #
    # @param severity [Integer, nil] Severity of the message
    # @param message [String, #call => String, nil] Message string, Proc returning the message for lazy evaluation,
    #   or nil if the message is given by the progname or a block
    # @param progname [String, nil] Program name to be logged if the message is nil
    # @yield The optional code returning the message to log
    # @yieldreturn [String] The message to log
    def log_message(severity, message, progname, &)
      @logger.public_send(SEVERITY_METHODS.fetch(severity || ::Logger::UNKNOWN, :unknown)) do
        resolved = resolve_message(message, progname, &)
        prefix = fields_prefix
        prefix.empty? ? resolved.to_s : "#{prefix} - #{resolved}"
      end
    end

    # Get the fields to be prefixed to logged messages, formatted
    #
    # @return [String] The formatted fields prefix
    def fields_prefix
      @fields.map { |field| "[#{field}]" }.join(' ')
    end

    # Resolve the message to be logged.
    # The block has priority over the message and progname parameters, and Procs are called to get their result.
    #
    # @param message [String, #call => String, nil] Message string or Proc returning the message
    # @param progname [String, nil] Program name to be logged if the message is nil
    # @yield The optional code returning the message to log
    # @yieldreturn [String] The message to log
    # @return [String] The message to be logged
    def resolve_message(message, progname, &)
      resolved =
        if block_given?
          yield
        elsif message.nil?
          progname
        else
          message
        end
      resolved.respond_to?(:call) ? resolved.call : resolved
    end
  end
end
