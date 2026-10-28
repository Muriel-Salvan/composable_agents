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
    # * A proc receives the agent's instance and returns either `nil` (no retry)
    #   or a {RetryPolicy}.
    # * The run method is wrapped: it calls the original run, then evaluates the
    #   registered procs in order until one returns a non-nil {RetryPolicy}.
    # * If a proc decides to retry: wait for `wait_secs` seconds, then call the
    #   `modifier` proc (if any), then call run again.
    #
    # # Retries are purely condition-driven: exceptions raised inside `run` are
    # # not caught by this mixin; retries only happen when a registered proc
    # # explicitly returns a non-nil retry policy.
    #
    # # Naming
    #
    # The {RetryPolicy} name and its `wait_secs` / `modifier` properties are
    # kept from the draft; they are clear and self-documenting.
    module Retriable
      # Configuration deciding whether and how an agent should be retried.
      #
      # @!attribute [rw] wait_secs
      #   @return [Integer, Float] number of seconds to wait before retrying.
      #     Defaults to 0.
      # @!attribute [rw] modifier
      #   @return [Proc, nil] proc called with the agent instance before
      #     retrying. Defaults to doing nothing.
      RetryPolicy = Struct.new(:wait_secs, :modifier, keyword_init: true) do
        # @return [Integer, Float] wait time, defaulting to 0 when nil.
        def wait_secs
          self[:wait_secs] || 0
        end
      end

      # @!group Public API

      # Register a proc that evaluates whether the agent should be retried
      # after a run.
      #
      # This method can be called several times with different procs to define
      # various criteria to retry. The registered procs are evaluated in the
      # order they were registered.
      #
      # @param proc [Proc] the retry condition proc
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
      # @param proc [Proc] the retry condition proc
      # @yield the code block in which the proc is active
      # @return [Object] the value returned by the block
      def with_retry_on(proc, &block)
        retry_on(proc)
        yield
      ensure
        retry_policies.delete(proc)
      end

      # Wrap the agent's run method with retry logic.
      #
      # It calls the original run, then evaluates the registered procs in
      # order until one returns a non-nil {RetryPolicy}. If one does, it waits
      # for the policy's `wait_secs`, applies the `modifier` proc (if any)
      # and calls run again.
      #
      # @param input_artifacts [Hash{Symbol => Object}] input artifacts
      # @return [Hash{Symbol => Object}] output artifacts from the last run
      def run(**input_artifacts)
        output_artifacts = nil
        loop do
          output_artifacts = super
          policy = nil
          retry_policies.each do |policy_proc|
            policy = policy_proc.call(self)
            break if policy
          end
          break unless policy

          wait_secs = policy.wait_secs
          sleep(wait_secs) if wait_secs.positive?
          policy.modifier&.call(self)
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
