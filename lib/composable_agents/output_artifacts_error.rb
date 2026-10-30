module ComposableAgents
  # Custom exception raised when output artifacts have errors.
  # The whole output_artifacts_errors structure is embedded in the exception.
  class OutputArtifactsError < StandardError
    # @return [Hash{Symbol => String}] The list of artifacts in error, with their corresponding error message.
    attr_reader :output_artifacts_errors

    # Initialize a new OutputArtifactsError with the errors hash.
    #
    # @param output_artifacts_errors [Hash] Hash of artifact names to errors
    def initialize(output_artifacts_errors)
      @output_artifacts_errors = output_artifacts_errors
      super("Output artifacts errors: #{output_artifacts_errors.inspect}")
    end
  end
end
