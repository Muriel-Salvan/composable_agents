module ComposableAgents
  module Mixins
    # Mixin that adds user interaction capabilities to AiAgent::Agent agents.
    # An agent can define the method #answer_to to handle the question.
    # Default handling is asking the question on the terminal.
    module UserInteraction
      # Returns the list of tools available for this agent
      #
      # @return [Array<Agents::Tool>] List of tools
      def agent_tools
        super + [AiAgents::Tools::AskUserTool.new(self)]
      end

      # Answer an agent's question
      #
      # @param question [String] The agent's question
      # @return [String] The answer that should be sent back to the agent
      def answer_to(question)
        track_message(message: question, author: "Agent #{name}", question: true)
        answer =
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
        track_message(message: answer, author: 'User')
        answer
      end
    end
  end
end
