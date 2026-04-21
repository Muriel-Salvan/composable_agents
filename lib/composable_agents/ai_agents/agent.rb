require 'agents'

module ComposableAgents
  # All agents from this module work with the awesome ai-agents Rubygem
  module AiAgents
    # Agent implementation that uses an ai-agent's AgentRunner.
    class Agent < PromptDrivenAgent
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

      private

      # Prepare the context for a given rendered system prompt
      #
      # @param system_prompt [Object] The rendered system prompt
      # @param input_artifacts [Hash<Symbol,Object>] The input artifacts content, per artifact name
      # @param output_artifacts [Hash<Symbol,Object>] The output artifacts to be filled by subsequent prompts, per artifact name
      # @yield Code to be executed with the context prepared
      def with_system_prompt(system_prompt, input_artifacts:, output_artifacts:)
        artifact_tools = [
          Tools::CreateArtifactTool.new(output_artifacts),
          Tools::GetArtifactTool.new(input_artifacts)
        ]
        @agent_runner = Agents::AgentRunner.new(
          (
            [
              Agents::Agent.new(
                model: @model,
                name: @name,
                params: @params,
                instructions: system_prompt
              )
            ] + @handoff_agents
          ).map { |agent| agent.clone(tools: agent.tools + artifact_tools) }
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
        raise "Error: #{result.error}\n#{result.error.backtrace.join("\n")}" unless result.error.nil?

        @context = result.context
        result.output
      end
    end
  end
end
