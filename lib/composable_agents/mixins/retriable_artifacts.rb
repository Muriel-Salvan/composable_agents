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
      #
      # @param artifacts_errors_max_retries [Integer] Maximum number of retries when output
      #   artifacts are missing or in error. Defaults to 3. When the number of retries
      #   exceeds this value, a {ArtifactsErrorsMaxRetriesExceededError} is raised.
      # @param args [Array] Arguments passed to the parent initializer
      # @param kwargs [Hash] Keyword arguments passed to the parent initializer
      def initialize(*args, artifacts_errors_max_retries: 3, **kwargs)
        super(*args, **kwargs)
        @retriable_artifacts_user_instructions = nil
        max_retries = artifacts_errors_max_retries
        artifacts_errors_retries = 0
        last_artifact_keys = nil
        retry_on(
          proc do |_agent, exception|
            output_artifacts_errors = exception.is_a?(OutputArtifactsError) ? exception.output_artifacts_errors : {}
            missing = missing_artifacts(output_artifacts_errors)
            artifact_keys = missing.keys

            # Reset counter when the set of artifacts needing retry changes between iterations
            if artifact_keys != last_artifact_keys
              artifacts_errors_retries = 0
              last_artifact_keys = artifact_keys
            end

            # If no artifacts need retry, return nil (no retry)
            if artifact_keys.empty?
              nil
            elsif artifacts_errors_retries >= max_retries
              artifacts_errors_retries = 0
              last_artifact_keys = []
              raise ArtifactsErrorsMaxRetriesExceededError,
                    "Maximum number of retries (#{max_retries}) exceeded. Missing or errored artifacts: #{artifact_keys.join(', ')}"
            else
              artifacts_errors_retries += 1
              { new_input_artifacts: { user_instructions: missing_output_user_instructions(missing) } }
            end
          end
        )
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
