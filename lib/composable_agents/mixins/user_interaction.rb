module ComposableAgents
  module Mixins
    # Mixin that adds user interaction capabilities to AiAgent::Agent agents.
    module UserInteraction
      # Returns the list of tools available for this agent
      #
      # @return [Array<Agents::Tool>] List of tools
      def agent_tools
        super + [AiAgents::Tools::AskUserTool.new]
      end
    end
  end
end
