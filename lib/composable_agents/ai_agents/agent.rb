require 'agents'

module ComposableAgents
  # All agents from this module work with the awesome ai-agents Rubygem
  module AiAgents
    # Agent implementation that uses an ai-agent's AgentRunner.
    class Agent < PromptDrivenAgent
      # [String] Model used by this agent
      attr_reader :model

      # Initialize a new agent with a list of ai-agents' Agents to be used with an AgentRunner
      #
      # @param model [String] Model to be used
      # @param params [Hash<Symbol, Object>] Additional parameters to give to the ai-agents' agent
      # @param handoff_agents [Array<Agents::Agent>] The list of additional agents that can be used for handoffs.
      def initialize(
        *args,
        model: Agents.configuration.default_model,
        params: {},
        handoff_agents: [],
        **kwargs
      )
        super(*args, **kwargs)
        @model = model
        @params = params
        @handoff_agents = handoff_agents
        @context = {}
      end

      # Export the agent state for persistence
      #
      # @return [Object] Serialized state that can be marshalled to JSON
      def export_state
        super.merge(
          'context' => Marshal.dump(@context)
        )
      end

      # Import the agent state from persistence
      #
      # @param state [Object] Serialized state
      def import_state(state)
        super
        @context = Marshal.load(state['context'])
      end

      private

      # Prepare the context for a given rendered system prompt
      #
      # @param system_prompt [Object] The rendered system prompt
      # @param input_artifacts [Hash<Symbol,Object>] The input artifacts content, per artifact name
      # @param output_artifacts [Hash<Symbol,Object>] The output artifacts to be filled by subsequent prompts, per artifact name
      # @yield Code to be executed with the context prepared
      def with_system_prompt(system_prompt, input_artifacts:, output_artifacts:)
        @agent_runner = Agents::AgentRunner.new(
          [
            Agents::Agent.new(
              model: @model,
              name: @name,
              params: @params,
              instructions: system_prompt,
              tools: [
                Tools::CreateArtifactTool.new(output_artifacts),
                Tools::GetArtifactTool.new(input_artifacts)
              ] + agent_tools
            )
          ] + @handoff_agents
        )
        yield
      end

      # Process a user prompt.
      # Prerequisites:
      # * This method is always called within a with_system_prompt block.
      #
      # @param user_prompt [Object] The rendered user prompt
      # @return [String] The output of the prompt
      def prompt(user_prompt)
        result = @agent_runner.run(user_prompt, context: @context)
        unless result.error.nil?
          raise <<~EO_ERROR.strip
            Error: #{result.error.detailed_message}
            #{result.error.backtrace.join("\n")}
            #{result.error.response.response_body}
          EO_ERROR
        end

        @context = result.context
        result.output
      end

      # Returns the list of tools available for this agent
      #
      # @return [Array<Agents::Tool>] List of tools
      def agent_tools
        []
      end
    end
  end
end
