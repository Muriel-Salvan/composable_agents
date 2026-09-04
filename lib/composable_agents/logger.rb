require 'logger'

module ComposableAgents
  # Logger to be used by agents.
  # This is a standard Ruby Logger (inheriting from ::Logger) that formats messages with a UTC timestamp and severity.
  # It also supports prefixing fields to messages (like the agent's full name) using the #tagged method,
  #   which returns a proxy compatible with any Ruby-like logger: fields are then prepended to the logged messages
  #   themselves, and silently ignored by loggers not supporting them.
  class Logger < ::Logger
    # @!group Public API

    class << self
      # Get the default singleton logger instance
      #
      # @return [Logger] The default logger instance
      def instance
        @instance ||= new
      end
    end

    # Constructor.
    # Unless overridden by the caller, the default level follows the COMPOSABLE_AGENTS_DEBUG environment variable
    #   (DEBUG when it is set to 1, INFO otherwise), and the default formatter outputs messages as
    #   `[UTC timestamp] [SEVERITY] message`.
    #
    # @param logdev [IO, String, #write, nil] Log device to be used, defaulting to standard output
    # @param args [Array<Object>] Positional arguments to be given to ::Logger (shifting parameters...)
    # @param kwargs [Hash{Symbol => Object}] Optional parameters to be given to ::Logger (level, formatter...)
    def initialize(logdev = $stdout, *args, **kwargs)
      super
      self.level = ENV['COMPOSABLE_AGENTS_DEBUG'] == '1' ? DEBUG : INFO unless kwargs.key?(:level)
      return if kwargs.key?(:formatter)

      self.formatter = proc do |severity, _datetime, _progname, message|
        "[#{Time.now.utc.strftime('%F %T')}] [#{severity}] #{message}\n"
      end
    end

    # Get a logger proxy that prefixes the given fields to logged messages.
    # The returned proxy is compatible with any Ruby-like logger.
    #
    # @param fields [Array<String>] Fields to be prefixed to each logged message
    # @return [Tagged] The fields-prefixing logger proxy
    def tagged(*fields)
      Tagged.new(self, fields)
    end
  end
end
