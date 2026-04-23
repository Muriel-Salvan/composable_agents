module ComposableAgents
  module Mixins
    # Mixin providing input/output artifact validation functionality for Agents.
    # The contracts should be provided by methods named #input_artifacts_contracts and #output_artifacts_contracts
    # A contract can be one of the following objects:
    # * [String] The artifact's description
    # * [Hash<Symbol, Object>] The artifact's detailed contract. It can contain the following attributes:
    #   * description [String] The artifact's description. This is also the default value when the contract is expressed as a String.
    #   * optional [Boolean] Is the artifact optional? Defaults to false.
    module ArtifactContract
      # Raised when required input artifacts are missing
      class MissingInputArtifactError < RuntimeError
      end

      # Raised when expected output artifacts are missing
      class MissingOutputArtifactError < RuntimeError
      end

      # Constructor
      #
      # @param input_artifacts [Hash<Symbol, Object>, NilClass] Hash of input artifact names and their contracts,
      #   or nil if provided through the input_artifacts_contracts method
      # @param output_artifacts [Hash<Symbol, Object>, NilClass] Hash of output artifact names and their contracts,
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
        output_artifacts = super(**input_artifacts.slice(*normalized_input_artifacts_contracts.keys))
        validate_output_artifacts(output_artifacts)
        output_artifacts
      end

      private

      # Define input artifacts contracts
      #
      # @return [Hash<Symbol, Object>] Set of input artifacts contract, per artifact name
      def input_artifacts_contracts
        # If the contracts were given by the constructor, use them
        (defined?(super) ? super : {}).merge(@input_artifacts_contracts || {})
      end

      # Define output artifacts contracts
      #
      # @return [Hash<Symbol, Object>] Set of output artifacts contract, per artifact name
      def output_artifacts_contracts
        # If the contracts were given by the constructor, use them
        (defined?(super) ? super : {}).merge(@output_artifacts_contracts || {})
      end

      # Normalize artifacts' contracts
      #
      # @param artifacts_contracts [Hash<Symbol, Object>] The artifacts contracts to be normalized
      # @return [Hash<Symbol, Hash<Symbol, Object>>] The normalized artifacts contracts (always in their Hash form as described in the class documentation)
      def normalize_contracts(artifacts_contracts)
        artifacts_contracts.to_h do |name, contract_def|
          contract_def = { description: contract_def } unless contract_def.is_a?(Hash)
          [
            name,
            # Default values
            {
              description: 'Artifact',
              optional: false
            }.merge(contract_def)
          ]
        end
      end

      # Retrieve and memoize normalized input artifacts contracts
      #
      # @return [Hash<Symbol, Hash<Symbol, Object>>] Set of normalized input artifacts contract, per artifact name
      def normalized_input_artifacts_contracts
        @normalized_input_artifacts_contracts ||= normalize_contracts(input_artifacts_contracts)
      end

      # Retrieve and memoize normalized output artifacts contracts
      #
      # @return [Hash<Symbol, Hash<Symbol, Object>>] Set of normalized output artifacts contract, per artifact name
      def normalized_output_artifacts_contracts
        @normalized_output_artifacts_contracts ||= normalize_contracts(output_artifacts_contracts)
      end

      # Validate that all required input artifacts are present
      #
      # @param artifacts [Hash<Symbol, Object>] Input artifacts to validate
      # @raise [MissingInputArtifactError] If any required artifacts are missing
      def validate_input_artifacts(artifacts)
        artifacts_contracts = normalized_input_artifacts_contracts.reject { |_name, contract| contract[:optional] }
        missing_inputs = artifacts_contracts.keys - artifacts.keys
        return if missing_inputs.empty?

        raise MissingInputArtifactError, "Missing required input artifacts:\n#{
          missing_inputs.map do |key|
            "* #{key}: #{artifacts_contracts[key][:description]}"
          end.join("\n")
        }"
      end

      # Validate that all expected output artifacts are present
      #
      # @param artifacts [Hash<Symbol, Object>] Output artifacts to validate
      # @raise [MissingOutputArtifactError] If any expected artifacts are missing
      def validate_output_artifacts(artifacts)
        artifacts_contracts = normalized_output_artifacts_contracts.reject { |_name, contract| contract[:optional] }
        missing_outputs = artifacts_contracts.keys - artifacts.keys
        return if missing_outputs.empty?

        raise MissingOutputArtifactError, "Agent failed to produce expected output artifacts:\n#{
          missing_outputs.map do |key|
            "* #{key}: #{artifacts_contracts[key][:description]}"
          end.join("\n")
        }"
      end
    end
  end
end
