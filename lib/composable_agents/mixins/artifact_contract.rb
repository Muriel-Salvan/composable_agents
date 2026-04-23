module ComposableAgents
  module Mixins
    # Mixin providing input/output artifact validation functionality for Agents.
    # The contracts should be provided by methods named #input_artifacts_contracts and #output_artifacts_contracts
    module ArtifactContract
      # Raised when required input artifacts are missing
      class MissingInputArtifactError < RuntimeError
      end

      # Raised when expected output artifacts are missing
      class MissingOutputArtifactError < RuntimeError
      end

      # Constructor
      #
      # @param input_artifacts [Hash<Symbol, String>, NilClass] Hash of input artifact names and their descriptions,
      #   or nil if provided through the input_artifacts_contracts method
      # @param output_artifacts [Hash<Symbol, String>, NilClass] Hash of output artifact names and their descriptions,
      #   or nil if provided through the output_artifacts_contracts method
      def initialize(
        *args,
        input_artifacts: nil,
        output_artifacts: nil,
        **kwargs
      )
        super(*args, **kwargs)
        @input_artifacts_contracts = input_artifacts
        @output_artifacts_contracts = output_artifacts
      end

      # Execute the agent to generate some output artifacts based on some input artifacts.
      #
      # @param input_artifacts [Hash<Symbol,Object>] The input artifacts content
      # @return Hash<Symbol,Object> Output artifacts content
      # @raise [MissingInputArtifactError] If required input artifacts are missing
      # @raise [MissingOutputArtifactError] If expected output artifacts are missing after run
      def run(**input_artifacts)
        validate_input_artifacts(input_artifacts)
        output_artifacts = super(**input_artifacts.slice(*input_artifacts_contracts.keys))
        validate_output_artifacts(output_artifacts)
        output_artifacts
      end

      private

      # Define input artifacts contracts
      #
      # @return [Hash<Symbol, String>] Set of input artifacts description, per artifact name
      def input_artifacts_contracts
        # If the contracts were given by the constructor, use them
        @input_artifacts_contracts || super
      end

      # Define output artifacts contracts
      #
      # @return [Hash<Symbol, String>] Set of output artifacts description, per artifact name
      def output_artifacts_contracts
        # If the contracts were given by the constructor, use them
        @output_artifacts_contracts || super
      end

      # Validate that all required input artifacts are present
      #
      # @param artifacts [Hash<Symbol, Object>] Input artifacts to validate
      # @raise [MissingInputArtifactError] If any required artifacts are missing
      def validate_input_artifacts(artifacts)
        artifacts_contracts = input_artifacts_contracts
        missing_inputs = artifacts_contracts.keys - artifacts.keys
        return if missing_inputs.empty?

        raise MissingInputArtifactError, "Missing required input artifacts:\n#{
          missing_inputs.map do |key|
            "* #{key}: #{artifacts_contracts[key]}"
          end.join("\n")
        }"
      end

      # Validate that all expected output artifacts are present
      #
      # @param artifacts [Hash<Symbol, Object>] Output artifacts to validate
      # @raise [MissingOutputArtifactError] If any expected artifacts are missing
      def validate_output_artifacts(artifacts)
        artifacts_contracts = output_artifacts_contracts
        missing_outputs = artifacts_contracts.keys - artifacts.keys
        return if missing_outputs.empty?

        raise MissingOutputArtifactError, "Agent failed to produce expected output artifacts:\n#{
          missing_outputs.map do |key|
            "* #{key}: #{artifacts_contracts[key]}"
          end.join("\n")
        }"
      end
    end
  end
end
