module ComposableAgents
  module Mixins
    # Logging mixin for agents
    module Logger
      # Check if debug mode is enabled
      #
      # @return [Boolean] True if debug mode is enabled
      def self.debug?
        !ENV['COMPOSABLE_AGENTS_DEBUG'].nil?
      end

      private

      # Log debug message only if debug mode is enabled
      #
      # @param message [String, Proc] Message string or Proc returning message for lazy evaluation
      def log_debug(message)
        return unless Logger.debug?

        log(message, severity: :debug)
      end

      # Log info message
      #
      # @param message [String, #call => String] Message string or Proc returning message for lazy evaluation
      def log_info(message)
        log(message, severity: :info)
      end

      # Log a message with severity
      #
      # @param message [String, #call => String] Message string or Proc returning message for lazy evaluation
      # @param severity [Symbol] Severity
      def log(message, severity: :info)
        puts "[#{Time.now.utc.strftime('%F %T')}] [#{severity.to_s.upcase}] - #{message.is_a?(String) ? message : message.call}"
      end
    end
  end
end
