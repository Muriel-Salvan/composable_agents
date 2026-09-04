module ComposableAgents
  module AiAgents
    # Collection of tools that can be used with ai-agents' agents
    module Tools
      # Base class for all tools used by agents.
      # It provides a logger to all tools, that can be set to any Ruby-like logger
      #   and defaults to ComposableAgents::Logger's singleton instance.
      class BaseTool < Agents::Tool
        # @!group Internal

        # Constructor
        #
        # @param logger [::Logger] Logger to be used by this tool. Any Ruby-like logger is accepted.
        #   Defaults to ComposableAgents::Logger's singleton instance.
        def initialize(logger: ComposableAgents::Logger.instance)
          super()
          @logger = logger
        end
      end
    end
  end
end
