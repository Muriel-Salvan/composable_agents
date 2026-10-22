require 'base64'
require 'agents'

module ComposableAgents
  # All agents from this module work with the awesome ai-agents Rubygem
  module AiAgents
    # Agent implementation that uses an ai-agent's AgentRunner.
    # This agent publishes the following run information:
    # - usage [Hash] Cumulative usage (cost and tokens) of the LLM calls made during the run.
    #   This information is published in realtime, as soon as the AgentRunner completes LLM calls.
    #   Here are the properties it contains:
    #   - cost [Float] Cumulative monetary cost of all LLM calls of the run.
    #     This cost is computed by RubyLLM from the model's pricing in its registry: it is best-effort,
    #     as models with incomplete pricing information can have their cost underestimated.
    #   - input_tokens [Integer] Cumulative number of input tokens of all LLM calls of the run.
    #   - output_tokens [Integer] Cumulative number of output tokens of all LLM calls of the run.
    #   - cache_read_tokens [Integer] Cumulative number of tokens read from cache by all LLM calls of the run.
    #   - cache_write_tokens [Integer] Cumulative number of tokens written to cache by all LLM calls of the run.
    #   - context_tokens [Integer, nil] Number of context tokens consumed by the last LLM call of the run.
    #     This property is not cumulative, as each LLM call contains the full context.
    #   - context_tokens_limit [Integer, nil] Maximum context window limit of the model used, or nil if unknown.
    class Agent < PromptDrivenAgent
      # @!group Public API

      # Initialize a new agent with a list of ai-agents' Agents to be used with an AgentRunner
      #
      # @param model [String] Model to be used
      # @param params [Hash{Symbol => Object}] Additional parameters to give to the ai-agents' agent
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

      # Return the full name of the agent.
      # This method is intended to be overridden by subclasses to give better full names, tailored to the kind of agent.
      # The full name can be used in logs and traces to better identify the agent.
      #
      # @return [String] The agent's full name
      def full_name
        "#{name || 'Unnamed'} (AiAgent #{@model})"
      end

      # Execute the agent to generate some output artifacts based on some input artifacts.
      # Also reset the usage statistics accumulated for this run (published realtime in the run info).
      #
      # @param user_instructions [Object, nil] Instructions for the user prompt, that will be rendered.
      #   The kind of instructions that can be given are defined by the Instructions's constructor (see Instructions#initialize).
      # @param input_artifacts [Hash{Symbol => Object}] The input artifacts content, per artifact name
      # @return [Hash{Symbol => Object}] The output artifacts
      def run(user_instructions: nil, **input_artifacts)
        @llm_call_responses = []
        super
      end

      # @!group Internal

      # Export the agent state for persistence
      #
      # @return [Object] Serialized state that can be marshalled to JSON
      def export_state
        super.merge(deep_transform_keys(context: Base64.encode64(Marshal.dump(@context)), &:to_s))
      end

      # Import the agent state from persistence
      #
      # @param state [Object] Serialized state
      def import_state(state)
        super
        @context = Marshal.load(Base64.decode64(deep_transform_keys(state, &:to_sym)[:context]))
      end

      private

      # Get the agent runner.
      # Memoize it.
      #
      # @return [Agents::AgentRunner] The agent runner to be used
      def agent_runner
        @agent_runner ||= Agents::AgentRunner.new(
          [
            Agents::Agent.new(
              model: @model,
              name:,
              params: @params,
              instructions: @system_prompt,
              tools: [
                Tools::CreateArtifactTool.new(self, logger:),
                Tools::GetArtifactTool.new(@input_artifacts, logger:)
              ] + agent_tools
            )
          ] + @handoff_agents
        ).on_llm_call_complete { |_agent_name, _model, response| track_llm_usage(response) }
      end

      # Track usage (cost and tokens) of an LLM call, and publish it realtime in the run info.
      # The usage of all LLM calls of the run is summed to give the run's cumulative usage.
      #
      # @param response [RubyLLM::Message] The response of the LLM call
      def track_llm_usage(response)
        # Some responses have no usage metrics (eg. RubyLLM::Tool::Halt responses, or responses without token data)
        return unless response.tokens

        @llm_call_responses << response
        usages = @llm_call_responses
        last_response = usages.last
        publish_run_info(
          usage: {
            cost: usages.sum { |run_usage| llm_call_cost(run_usage) },
            input_tokens: usages.sum { |run_usage| run_usage.tokens&.input || 0 },
            output_tokens: usages.sum { |run_usage| run_usage.tokens&.output || 0 },
            cache_read_tokens: usages.sum { |run_usage| run_usage.tokens&.cache_read || 0 },
            cache_write_tokens: usages.sum { |run_usage| run_usage.tokens&.cache_write || 0 },
            # Context tokens are not summed, as each LLM call contains the full context: keep the last call's value.
            context_tokens: llm_call_context_tokens(last_response),
            context_tokens_limit: llm_call_context_tokens_limit(last_response)
          }
        )
      end

      # Compute the monetary cost of a single LLM call.
      # The cost is computed by RubyLLM from the model's pricing in its registry.
      # Best-effort: components with unknown pricing are not counted (their value is nil).
      #
      # @param response [RubyLLM::Message] The response of the LLM call
      # @return [Float] The monetary cost of the LLM call
      def llm_call_cost(response)
        return 0.0 unless response.respond_to?(:cost)

        cost = response.cost
        %i[input output cache_read cache_write thinking].sum(0.0) { |component| cost.public_send(component) || 0.0 }
      end

      # Compute the number of context tokens consumed by a single LLM call.
      # Each LLM call contains the full context of the conversation, plus the tokens generated in its response.
      #
      # @param response [RubyLLM::Message] The response of the LLM call
      # @return [Integer] Number of context tokens consumed by the LLM call
      def llm_call_context_tokens(response)
        tokens = response.tokens
        %i[input output cache_read cache_write thinking].sum { |component| tokens.public_send(component) || 0 }
      end

      # Get the context window limit of the model used by a single LLM call.
      #
      # @param response [RubyLLM::Message] The response of the LLM call
      # @return [Integer, nil] Maximum context window limit of the model, or nil if unknown
      def llm_call_context_tokens_limit(response)
        response.model_info&.context_window
      end

      # Process a user prompt.
      #
      # @param user_prompt [String] The rendered user prompt
      # @return [String] The output of the prompt
      def prompt(user_prompt)
        result = agent_runner.run(user_prompt, context: @context)
        unless result.error.nil?
          raise <<~EO_ERROR.strip
            Error: #{result.error.detailed_message}
            #{result.error.backtrace.join("\n")}
            #{result.error.response.response_body if result.error.respond_to?(:response)}
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
