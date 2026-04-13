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

      class << self
        def included(base)
          # Extend the base class with the class methods
          base.extend ClassMethods
        end

        alias prepended included
      end

      # Class methods for artifact declaration
      module ClassMethods
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

      # Run the agent with a set of input artifacts and get the correspondong output artifacts.
      #
      # @param input_artifacts [Hash<Symbol,Object>] The input artifacts content
      # @return Hash<Symbol,Object> Output artifacts content
      # @raise [MissingInputArtifactError] If required input artifacts are missing
      # @raise [MissingOutputArtifactError] If expected output artifacts are missing after run
      def run(input_artifacts: {})
        validate_input_artifacts(input_artifacts)
        output_artifacts = super
        validate_output_artifacts(output_artifacts)
        output_artifacts
      end

      private

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
end
