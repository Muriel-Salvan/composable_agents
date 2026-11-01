module ComposableAgents
  # Custom exception raised when the maximum number of retries for output artifacts
  # errors (missing or in error) is exceeded and the run cannot succeed.
  class ArtifactsErrorsMaxRetriesExceededError < StandardError
  end
end
