module ComposableAgents
  # Abstract computational unit that transforms inputs into outputs.
  # Agents may internally use LLMs, tools, or other agents.
  # Agents are stateless: they take input artifacts and return output artifacts.
  class Agent
    # Constructor
    #
    # @param composable_agents_dir [String] Base directory where composable agents can store data
    # @param debug [Boolean] Enable debug logging
    def initialize(composable_agents_dir: '.composable_agents', debug: !ENV['COMPOSABLE_AGENTS_DEBUG'].nil?)
      @composable_agents_dir = composable_agents_dir
      @debug = debug
    end

    # Run the agent with a set of input artifacts and get the correspondong output artifacts.
    #
    # @param input_artifacts [Hash<Symbol,Object>] The input artifacts content
    # @return Hash<Symbol,Object> Output artifacts content
    def run(input_artifacts: {})
      raise NotImplementedError, 'This method should be implemented by an Agent subclass'
    end

    private

    # Log debug message only if debug mode is enabled
    #
    # @param message [String, Proc] Message string or Proc returning message for lazy evaluation
    def log_debug(message)
      return unless @debug

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
