module ComposableAgentsTest
  module Helpers
    include Cline
    include Debug
    include PromptDrivenAgents

    # Instantiate an agent using the Markdown prompt rendering strategy.
    #
    # @param args [Array] Args to be given to the agent's constructor
    # @param kwargs [Hash] Keyword args to be given to the agent's constructor
    # @return [ComposableAgents::PromptDrivenAgent] Agent to be tested
    def agent_for_markdown(*args, **kwargs)
      Class.new(ComposableAgents::PromptDrivenAgent) do
        include ComposableAgents::PromptRenderingStrategy::Markdown

        # @return [Hash{Symbol => Object}] The input artifacts that are set using run calls
        attr_accessor :input_artifacts
      end.new(*args, **kwargs)
    end

    # Instantiate an agent using the MarkdownHeavy prompt rendering strategy,
    # with ArtifactContract mixin prepended.
    #
    # @param args [Array] Args to be given to the agent's constructor
    # @param context [Object] Context to be given to the agent
    # @param kwargs [Hash] Keyword args to be given to the agent's constructor
    # @return [ComposableAgents::PromptDrivenAgent] Agent to be tested
    def agent_for_markdown_heavy(*args, context: {}, **kwargs)
      Class.new(ComposableAgents::PromptDrivenAgent) do
        prepend ComposableAgents::Mixins::ArtifactContract
        include ComposableAgents::PromptRenderingStrategy::MarkdownHeavy

        # Constructor
        #
        # @param args [Array] Args to be given to the agent's constructor
        # @param context [Object] Context to be given to the agent
        # @param kwargs [Hash] Keyword args to be given to the agent's constructor
        def initialize(*args, context:, **kwargs)
          super(*args, **kwargs)
          @context = context
        end

        # @return [Hash{Symbol => Object}] The input artifacts that are set using run calls
        attr_accessor :input_artifacts
      end.new(*args, context:, **kwargs)
    end
  end
end
