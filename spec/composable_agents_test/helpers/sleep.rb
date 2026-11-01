module ComposableAgentsTest
  module Helpers
    # Helpers for prompt-driven agents testing
    # Helpers for mocking sleep in tests
    #
    # mock_sleeps(agent) - Sets up a spy on agent.sleep that captures the first argument
    # of each sleep call into @sleep_calls array AND makes sleep return nil.
    # Returns the @sleep_calls array for use in expect statements.
    #
    # Usage in tests:
    #   mock_sleeps(agent)  # sets up the spy
    #   sleep_calls         # returns the captured array (accessor)
    #
    module Sleep
      # Sets up a spy on agent.sleep that captures the first argument of each sleep call
      # into @sleep_calls array AND makes sleep return nil.
      # Returns the @sleep_calls array for use in expect statements.
      #
      # Usage in tests:
      #   mock_sleeps(agent)  # sets up the spy
      #
      # @param agent [Object] the agent instance to spy on
      # @return [Array] the @sleep_calls array captured from sleep calls
      def mock_sleeps(agent)
        @sleep_calls ||= []
        allow(agent).to receive(:sleep) do |*args|
          @sleep_calls << args.first
        end
      end

      # Returns the captured array of sleep call arguments.
      #
      # @return [Array] the @sleep_calls array containing all captured sleep arguments
      def sleep_calls
        @sleep_calls || []
      end
    end
  end
end
