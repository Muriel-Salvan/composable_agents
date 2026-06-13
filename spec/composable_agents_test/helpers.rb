module ComposableAgentsTest
  module Helpers
    # @return [Boolean] Are we in test debug mode?
    def self.debug?
      ENV['TEST_DEBUG'] == '1'
    end

    # Log debug a message
    #
    # @param message [String, nil] The message to log debug, or nil if given by a proc returning the message for lazy evaluation
    # @yield The optional code returning the message to log in case of debug
    # @yieldreturn [String] The message to log
    def log_debug(message = nil)
      return unless Debug.debug?

      puts "[CLINE TEST DEBUG] - #{block_given? ? yield : message}"
    end

    # Expect conversation to follow a given sequence.
    # This validates the authors and messages.
    # It also makes sure that timestamps are ordered properly and with a proper format.
    #
    # @param conversation [Array<Hash{Symbol => Object}>] The recorded conversation.
    # @param expected_conversation [Array<Hash{Symbol => Object}>] The expected conversation.
    #   If object values of the expected conversation ar Regexp, then pattern matching is used instead of equality.
    def expect_conversation(conversation, expected_conversation)
      expect(conversation.size).to eq expected_conversation.size
      conversation.zip(expected_conversation).each do |message, expected_message|
        # Normalize messages with some default values
        message = message.except(:at)
        expected_message = {
          question: false
        }.merge(expected_message)
        expect(message.size).to eq expected_message.size
        message.each do |message_attr, message_value|
          if expected_message[message_attr].is_a?(Regexp)
            expect(message_value).to match expected_message[message_attr]
          else
            expect(message_value).to eq expected_message[message_attr]
          end
        end
      end
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
