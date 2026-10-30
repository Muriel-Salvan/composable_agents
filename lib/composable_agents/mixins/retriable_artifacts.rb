module ComposableAgents
  module Mixins
    # Mixin adding automatic retry of the run when output artifacts are missing on prompt-driven agents.
    # This mixin requires the following mixins to be prepended:
    # - The {ArtifactContract} mixin.
    # - The {Retriable} mixin.
    # This mixin requires to be prepended on an agent descending from {PromptDrivenAgent}.
    #
    # When prepended to an agent descending from PromptDrivenAgent, the run method will
    # automatically re-execute until all expected output artifacts have been provided.
    #
    # On retry, the overridden #run method uses a prompt asking for missing artifacts
    # as +user_instructions+ instead of the original one.
    # When the run raised an {OutputArtifactsError}, artifacts having errors are also
    # included in the prompt, taken from the exception data.
    module RetriableArtifacts
      # Initialize a new agent with the retry-on-missing-artifacts policy registered.
      def initialize(*args, **kwargs)
        super
        @overridden_user_instructions = nil
        retry_on(
          proc do |agent, exception|
            output_artifacts_errors = exception.is_a?(OutputArtifactsError) ? exception.output_artifacts_errors : {}
            missing = agent.send(:missing_artifacts, output_artifacts_errors)
            # TODO: Implement a max number of retries and throw an exception if it exceeds.
            missing.empty? ? nil : { modifier: proc { @overridden_user_instructions = missing_output_user_instructions(missing) } }
          end
        )
      end

      # Execute the agent to generate some output artifacts based on some input artifacts.
      # On retry, uses +@overridden_user_instructions+ (set by the retry policy's modifier)
      # instead of the original +user_instructions+.
      #
      # @param user_instructions [Object, nil] Instructions for the user prompt, that will be rendered.
      # @param input_artifacts [Hash{Symbol => Object}] The input artifacts content, per artifact name
      # @return [Hash{Symbol => Object}] The output artifacts
      def run(user_instructions: nil, **input_artifacts)
        if @overridden_user_instructions
          user_instructions = @overridden_user_instructions
          @overridden_user_instructions = nil
        end
        super
      end

      private

      # Compute the missing output artifacts with their descriptions and errors.
      #
      # @param output_artifacts_errors [Hash{Symbol => String}] Artifacts having errors, per artifact name,
      #   as given by the {OutputArtifactsError} raised by the run (or empty if none).
      # @return [Hash{Symbol => Hash{Symbol => Object}}] Missing artifacts, per artifact name.
      def missing_artifacts(output_artifacts_errors)
        normalized_output_artifacts_contracts
          .reject { |artifact_name, _artifact_description| @output_artifacts.key?(artifact_name) }
          .to_h do |artifact_name, artifact_description|
            [
              artifact_name,
              artifact_description.merge(output_artifacts_errors[artifact_name] ? { error: output_artifacts_errors[artifact_name] } : {})
            ]
          end
      end
    end
  end
end
