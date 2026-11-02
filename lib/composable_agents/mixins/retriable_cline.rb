require 'cline'

module ComposableAgents
  module Mixins
    # Mixin adding automatic retry of the run when Cline is raising errors.
    # This mixin requires the following mixins to be prepended:
    # - The {Retriable} mixin.
    # This mixin requires to be prepended on an agent descending from {ComposableAgents::Cline::Agent}.
    #
    # When prepended to an agent descending from ComposableAgents::Cline::Agent, the run method will
    # automatically re-execute while errors are being raised, using exponential backoff with jitter.
    module RetriableCline
      # Constructor
      #
      # @param cline_errors_max_retries [Integer] Maximum number of retries for Cline errors
      # @param cline_errors_retry_initial_delay_secs [Float] Initial delay in seconds before the first retry
      # @param cline_errors_retry_backoff_factor [Float] Backoff multiplier for each subsequent retry
      # @param cline_errors_retry_max_delay_secs [Float] Maximum delay in seconds between retries
      # @param cline_errors_retry_jitter [Float] Amount of random jitter to add to the delay
      def initialize(
        *args,
        cline_errors_max_retries: 3,
        cline_errors_retry_initial_delay_secs: 5,
        cline_errors_retry_backoff_factor: 2,
        cline_errors_retry_max_delay_secs: 60,
        cline_errors_retry_jitter: 0.1,
        **kwargs
      )
        super(*args, **kwargs)
        max_retries = cline_errors_max_retries
        initial_delay = cline_errors_retry_initial_delay_secs
        backoff_factor = cline_errors_retry_backoff_factor
        max_delay = cline_errors_retry_max_delay_secs
        jitter = cline_errors_retry_jitter
        retries = 0
        retry_on(
          proc do |_agent, exception|
            next nil if retries >= max_retries || CLINE_ERROR_CLASSES.none? { |klass| exception.is_a?(klass) }

            retries += 1
            delay = initial_delay * (backoff_factor**(retries - 1))
            delay *= (1 + (jitter * ((2 * rand) - 1))) if jitter.positive?
            retry_policy = { wait_secs: delay.clamp(0, max_delay) }
            if exception.is_a?(::Cline::Cli::UnexpectedInteractiveSessionError)
              retry_policy[:new_input_artifacts] = { user_instructions: INTERACTIVE_SESSION_USER_INSTRUCTIONS }
            end
            retry_policy
          end
        )
      end

      # @return [Array<Class>] List of Cline error classes that trigger a retry of the run when raised by Cline.
      CLINE_ERROR_CLASSES = [
        ComposableAgents::Cline::ClineError,
        ::Cline::Cli::UnexpectedExitStatusError,
        ::Cline::Cli::UnexpectedInteractiveSessionError
      ].freeze

      # @return [String] Default user instructions used to retry a run that raised an {::Cline::Cli::UnexpectedInteractiveSessionError}.
      INTERACTIVE_SESSION_USER_INSTRUCTIONS = <<~TEXT.freeze
        You are not running in interactive mode, so you will not receive any input from the user.
        If you were expecting to ask the user a question, you must find the best answer to your question by yourself
        and proceed without user input.
      TEXT
    end
  end
end
