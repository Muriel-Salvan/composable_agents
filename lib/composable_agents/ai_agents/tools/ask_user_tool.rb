module ComposableAgents
  module AiAgents
    module Tools
      # Tool that is used to ask the user for some input
      class AskUserTool < BaseTool
        # @!group Internal

        description <<~EO_DESCRIPTION
          Ask the user a question and wait for their response.
          If you need information from the user, call this tool instead of asking directly.
          Do not guess user input.
        EO_DESCRIPTION
        param :question, type: 'string', desc: 'Question to be asked to the user'

        # Constructor
        #
        # @param agent [Agent] The agent that is using this tool
        # @param logger [::Logger] Logger to be used by this tool. Any Ruby-like logger is accepted.
        #   Defaults to ComposableAgents::Logger's singleton instance.
        def initialize(agent, logger: ComposableAgents::Logger.instance)
          super(logger:)
          @agent = agent
        end

        # Perform the tool's action.
        # This is called by ai-agents when the model requires it.
        #
        # @param _tool_context [Agents::ToolContext] The tool context
        # @param question [String] The question asked
        # @return [String] The tool's response
        def perform(_tool_context, question:)
          @agent.ask(question)
        end
      end
    end
  end
end
