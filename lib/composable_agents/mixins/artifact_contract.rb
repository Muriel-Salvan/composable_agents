module ComposableAgents
  module Mixins
    # Mixin providing input/output artifact validation functionality for Agents
    module ArtifactContract
      # Raised when required input artifacts are missing
      class MissingInputArtifactError < RuntimeError
      end

      # Raised when expected output artifacts are missing
      class MissingOutputArtifactError < RuntimeError
      end

      # Initialize an agent with artifact definitions
      #
      # @param input_artifacts [Hash<Symbol, String>] Hash of input artifact names and their descriptions
      # @param output_artifacts [Hash<Symbol, String>] Hash of output artifact names and their descriptions
      def initialize(
        *args,
        input_artifacts: {},
        output_artifacts: {},
        **kwargs
      )
        @input_artifacts = input_artifacts
        @output_artifacts = output_artifacts
        super(*args, **kwargs)
      end

      # Run the agent with a set of input artifacts and get the corresponding output artifacts.
      #
      # @param input_artifacts [Hash<Symbol,Object>] The input artifacts content
      # @return Hash<Symbol,Object> Output artifacts content
      # @raise [MissingInputArtifactError] If required input artifacts are missing
      # @raise [MissingOutputArtifactError] If expected output artifacts are missing after run
      def run(input_artifacts: {})
        validate_input_artifacts(input_artifacts)
        output_artifacts = super(input_artifacts: input_artifacts.slice(*@input_artifacts.keys))
        validate_output_artifacts(output_artifacts)
        output_artifacts
      end

      private

      # Validate that all required input artifacts are present
      #
      # @param artifacts [Hash<Symbol, Object>] Input artifacts to validate
      # @raise [MissingInputArtifactError] If any required artifacts are missing
      def validate_input_artifacts(artifacts)
        missing_inputs = @input_artifacts.keys - artifacts.keys
        return if missing_inputs.empty?

        raise MissingInputArtifactError, "Missing required input artifacts:\n#{
          missing_inputs.map do |key|
            "* #{key}: #{@input_artifacts[key]}"
          end.join("\n")
        }"
      end

      # Validate that all expected output artifacts are present
      #
      # @param artifacts [Hash<Symbol, Object>] Output artifacts to validate
      # @raise [MissingOutputArtifactError] If any expected artifacts are missing
      def validate_output_artifacts(artifacts)
        missing_outputs = @output_artifacts.keys - artifacts.keys
        return if missing_outputs.empty?

        raise MissingOutputArtifactError, "Agent failed to produce expected output artifacts:\n#{
          missing_outputs.map do |key|
            "* #{key}: #{@output_artifacts[key]}"
          end.join("\n")
        }"
      end
    end
  end
end
