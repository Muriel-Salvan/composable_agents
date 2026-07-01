module ComposableAgents
  module Mixins
    # Mixin that adds user interaction capabilities to PromptDrivenAgent agents.
    # This defines the following methods:
    # - `#ask(question) -> answer` Calls the `#answer_to` method to get the answer to a question and logs the conversation.
    # An agent using this Mixin should define the private method `#answer_to`` to handle the question.
    # Default handling is asking the question on the terminal.
    module UserInteraction
      # @!group Public API

      # Answer an agent's question
      #
      # @param question [String] The agent's question
      # @return [String] The answer that should be sent back to the agent
      def ask(question)
        track_message(message: question, author: "Agent #{full_name}", question: true)
        answer = answer_to(question)
        track_message(message: answer, author: 'User')
        answer
      end

      private

      # Answer an agent's question
      #
      # @param question [String] The agent's question
      # @return [String] The answer that should be sent back to the agent
      def answer_to(question)
        if defined?(super)
          super
        else
          # Provide a default way from terminal
          puts
          puts "Agent is asking a question:\n#{question}"
          puts
          puts 'Write answer and hit Enter...'
          $stdin.gets.strip
        end
      end
    end
  end
end
