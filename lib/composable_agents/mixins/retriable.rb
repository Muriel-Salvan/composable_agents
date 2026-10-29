module ComposableAgents
  module Mixins
    # Mixin adding retriable capabilities to agents.
    #
    # An agent prepending this mixin can define retry conditions that are
    # evaluated at the end of each run. The first condition that decides to
    # retry triggers a wait and a re-execution of the run.
    #
    # # Public interface
    #
    # * `#retry_on(&block)` registers a new retry condition proc.
    # * `#with_retry_on(proc, &block)` registers a retry proc for the duration
    #   of a code block and unregisters it afterwards.
    #
    # # Behaviour
    #
    # * Each registered proc is kept in an internal array, in registration order.
    # * A proc receives the agent's instance and the exception raised by `run`
    #   (or `nil` if none) and returns either `nil` (no retry) or a policy hash
    #   with optional `:wait_secs` and optional `:modifier` keys.
    # * The run method is wrapped: it calls the original run, then evaluates the
    #   registered procs in order until one returns a non-nil policy hash.
    # * If `run` raised an exception and no proc returned a non-nil policy hash,
    #   the exception is re-raised to the caller.
    # * If a proc decides to retry: wait for `wait_secs` seconds, then call the
    #   `modifier` proc (if any), then call run again.
    #
    module Retriable
      # @!group Public API

      # Register a proc that evaluates whether the agent should be retried
      # after a run.
      #
      # This method can be called several times with different procs to define
      # various criteria to retry. The registered procs are evaluated in the
      # order they were registered.
      #
      # @param proc [Proc] the retry condition proc. It receives the agent's
      #   instance and the exception raised by `run` (or `nil` if none).
      #   - param agent [Agent] The agent for which the retry is considered.
      #   - param exception [Exception, nil] The exception that was raised by the run, or nil if none.
      #   - result [Hash\\{Symbol => Object}] Definition of the retry policy, with optional properties:
      #     - wait_secs [Integer, Float] Wait time in seconds before retrying (defaults to 0).
      #     - modifier [Proc] Code called to modify the agent's state before retrying (defaults to doing nothing).
      #       - param agent [Agent] The agent for which the retry is considered.
      # @return [self]
      def retry_on(proc)
        retry_policies << proc
        self
      end

      # Register a retry proc for the duration of a code block, then
      # unregister it when the block returns (even if it raises).
      #
      # The block can itself register other procs (with {#retry_on}) and
      # those are kept after the block ends; only the proc given to this
      # method is unregistered.
      #
      # @param proc [Proc] the retry condition proc (see #retry_on)
      # @yield the code block in which the proc is active
      def with_retry_on(proc, &)
        retry_on(proc)
        yield
      ensure
        retry_policies.delete(proc)
      end

      # Wrap the agent's run method with retry logic.
      #
      # It calls the original run, then evaluates the registered procs in
      # order until one returns a non-nil policy hash. Each proc receives
      # the agent's instance and the exception raised by `run` (or `nil` if
      # none). If `run` raised an exception and no proc returned a non-nil
      # policy hash, the exception is re-raised to the caller. If one does,
      # it waits for the policy's `wait_secs`, applies the `modifier` proc
      # (if any) and calls run again.
      #
      # @param input_artifacts [Hash{Symbol => Object}] input artifacts
      # @return [Hash{Symbol => Object}] output artifacts from the last run
      def run(**input_artifacts)
        output_artifacts = nil
        retry_index = 0
        loop do
          exception = nil
          begin
            output_artifacts = super
          rescue StandardError => e
            exception = e
          end
          policy = nil
          retry_policies.each do |policy_proc|
            policy = policy_proc.call(self, exception)
            break if policy
          end
          if policy
            retry_index += 1
            wait_secs = policy[:wait_secs] || 0
            logger.debug "Retry ##{retry_index}: re-running in #{wait_secs}s#{" (exception #{exception})" if exception}"
            sleep(wait_secs) if wait_secs.positive?
            policy[:modifier]&.call(self)
          else
            raise exception if exception

            break
          end
        end
        output_artifacts
      end

      private

      # @return [Array<Proc>] the registered retry condition procs
      def retry_policies
        @retry_policies ||= []
      end
    end
  end
end
