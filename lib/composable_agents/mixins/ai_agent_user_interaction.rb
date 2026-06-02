module ComposableAgents
  module Mixins
    # Mixin that adds user interaction capabilities to AiAgent::Agent agents.
    # This uses an AiAgent tool to then call the normal UserInteraction interface.
    module AiAgentUserInteraction
      # Hook used when this mixin is included in a base class
      #
      # @param base [Class] The base class
      def self.prepended(base)
        base.include(UserInteraction)
      end

      # Returns the list of tools available for this agent
      #
      # @return [Array<Agents::Tool>] List of tools
      def agent_tools
        super + [AiAgents::Tools::AskUserTool.new(self)]
      end
    end
  end
end
