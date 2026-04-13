require 'composable_agents/agent'

module ComposableAgents
  # Agent implementation that wraps a Ruby Proc for custom logic
  #
  # This agent allows wrapping arbitrary Ruby logic as an Agent by providing
  # a Proc that handles the transformation of input artifacts to output artifacts.
  class RubyAgent < Agent
    # Initialize a new RubyAgent with a processing proc
    #
    # @param processor [#call(Hash<Symbol, Object>) => Hash<Symbol, Object>] The agent logic.
    #   This proc will receive the input artifacts hash and must return a hash of output artifacts.
    #   - Param input_artifacts [Hash<Symbol, Object>] Input artifacts provided to the agent
    #   - Return [Hash<Symbol, Object>] Output artifacts produced by the agent
    def initialize(processor, *args, **kwargs)
      super(*args, **kwargs)
      @processor = processor
    end

    # Execute the agent by calling the wrapped Proc
    #
    # @param input_artifacts [Hash<Symbol,Object>] The input artifacts content, per artifact name
    # @return [Hash<Symbol,Object>] The output artifacts returned by the Proc
    def run(input_artifacts: {})
      @processor.call(input_artifacts)
    end
  end
end
