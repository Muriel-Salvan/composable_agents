module ComposableAgentsTest
  module Helpers
    # Expect conversation to follow a given sequence.
    # This validates the authors and messages.
    # It also makes sure that timestamps are ordered properly and with a proper format.
    #
    # @param conversation [Array<Hash<Symbol, String>>] The recorded conversation
    # @param expected_conversation [Array<Hash<Symbol, String>>] The expected conversation
    def expect_conversation(conversation, expected_conversation)
      expect(conversation.map { |message| message.except(:at) }).to eq(
        # Normalize expected_conversation with some default values
        expected_conversation.map do |message|
          {
            question: false
          }.merge(message)
        end
      )
      timestamps = conversation.map { |message| message[:at] }
      expect(timestamps.sort).to eq timestamps
    end

    # Instantiate an agent using the Markdown prompt rendering strategy.
    #
    # @param args [Array] Args to be given to the agent's constructor
    # @param kwargs [Hash] Keyword args to be given to the agent's constructor
    # @return [ComposableAgents::PromptDrivenAgent] Agent to be tested
    def agent_for_markdown(*args, **kwargs)
      Class.new(ComposableAgents::PromptDrivenAgent) do
        include ComposableAgents::PromptRenderingStrategy::Markdown
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
      end.new(*args, context:, **kwargs)
    end
  end
end
