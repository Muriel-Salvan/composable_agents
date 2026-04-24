module ComposableAgents
  module AiAgents
    module Tools
      # Tool that is used to ask the user for some input
      class AskUserTool < Agents::Tool
        include Mixins::Logger

        description <<~EO_DESCRIPTION
          Ask the user a question and wait for their response.
          If you need information from the user, call this tool instead of asking directly.
          Do not guess user input.
        EO_DESCRIPTION
        param :question, type: 'string', desc: 'Question to be asked to the user'

        # Perform the tool's action.
        # This is called by ai-agents when the model requires it.
        #
        # @param tool_context [Agents::ToolContext] The tool context
        # @param question [String] The question asked
        # @return [String] The tool's response
        def perform(_tool_context, question:)
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
