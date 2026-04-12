module ComposableAgents
  # Raised when required input artifacts are missing
  class MissingInputArtifactError < ArgumentError; end

  # Raised when expected output artifacts are missing
  class MissingOutputArtifactError < RuntimeError; end

  # Abstract computational unit that transforms inputs into outputs.
  # Agents may internally use LLMs, tools, or other agents.
  # Agents are stateless: they take input artifacts and return output artifacts.
  class Agent
    class << self
      # Declare expected input artifacts for this agent
      # @param artifacts [Hash<Symbol, String>] Hash of artifact names and their descriptions,
      #   or nil to only get artifacts
      # @return [Hash<Symbol, String>] The full set of input artifacts
      def input_artifacts(artifacts = nil)
        if artifacts
          @input_artifacts = artifacts
        else
          @input_artifacts ||= {}
        end
      end

      # Declare expected output artifacts for this agent
      # @param artifacts [Hash<Symbol, String>] Hash of artifact names and their descriptions,
      #   or nil to only get artifacts
      # @return [Hash<Symbol, String>] The full set of output artifacts
      def output_artifacts(artifacts = nil)
        if artifacts
          @output_artifacts = artifacts
        else
          @output_artifacts ||= {}
        end
      end

      # Inherit artifact definitions from parent class
      def inherited(subclass)
        subclass.input_artifacts(input_artifacts)
        subclass.output_artifacts(output_artifacts)
        super
      end
    end

    # Constructor
    #
    # @param composable_agents_dir [String] Base directory where composable agents can store data
    # @param debug [Boolean] Enable debug logging
    def initialize(composable_agents_dir: '.composable_agents', debug: !ENV['COMPOSABLE_AGENTS_DEBUG'].nil?)
      @composable_agents_dir = composable_agents_dir
      @debug = debug
    end

    # Safely run the agent with input validation before execution
    # and output validation after execution
    #
    # @param input_artifacts [Hash<Symbol,Object>] The input artifacts content
    # @return Hash<Symbol,Object> Validated output artifacts
    # @raise [MissingInputArtifactError] If required input artifacts are missing
    # @raise [MissingOutputArtifactError] If expected output artifacts are missing after run
    def safe_run(input_artifacts: {})
      validate_input_artifacts(input_artifacts)
      output_artifacts = run(input_artifacts: input_artifacts)
      validate_output_artifacts(output_artifacts)
      output_artifacts
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

    # Implement this method in subclasses to define agent logic
    #
    # @param input_artifacts [Hash<Symbol,Object>] The input artifacts content, per artifact name
    # @return Hash<Symbol,Object> The output artifacts, per artifact name
    def run(input_artifacts: {})
      raise NotImplementedError, 'This method should be implemented by an Agent subclass as a private method'
    end

    # Validate that all required input artifacts are present
    #
    # @param artifacts [Hash<Symbol, Object>] Input artifacts to validate
    # @raise [MissingInputArtifactError] If any required artifacts are missing
    def validate_input_artifacts(artifacts)
      missing_inputs = self.class.input_artifacts.keys - artifacts.keys
      return if missing_inputs.empty?

      raise MissingInputArtifactError, "Missing required input artifacts:\n#{
        missing_inputs.map do |key|
          "* #{key}: #{self.class.input_artifacts[key]}"
        end.join("\n")
      }"
    end

    # Validate that all expected output artifacts are present
    #
    # @param artifacts [Hash<Symbol, Object>] Output artifacts to validate
    # @raise [MissingOutputArtifactError] If any expected artifacts are missing
    def validate_output_artifacts(artifacts)
      missing_outputs = self.class.output_artifacts.keys - artifacts.keys
      return if missing_outputs.empty?

      raise MissingOutputArtifactError, "Agent failed to produce expected output artifacts:\n#{
        missing_outputs.map do |key|
          "* #{key}: #{self.class.output_artifacts[key]}"
        end.join("\n")
      }"
    end
  end
end
