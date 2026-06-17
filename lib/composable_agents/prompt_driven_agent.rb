require 'time'

module ComposableAgents
  # Agent implementation that uses a prompt rendering strategy to render prompts for a prompting engine.
  # The following prompts are considered:
  # - A system prompt, that defines the Agent's behaviour, or persona.
  # - User prompts, that are used as user inputs guiding the agent.
  # - Retry prompts, used to tell the Agent that the task at hand is still incomplete and needs more work.
  #     For example when an artifact has not been created, and the agent needs to try it again.
  #
  # Prompt rendering strategies are useful because different prompt-driven agents would benefit from different
  #   prompt formats or structures (JSON, Markdown, explicit ordered lists, in-lining artifacts' contents without tools...).
  # This agent automatically records non-rendered conversation (prompts + outputs) in a `conversation` store, part of its state.
  class PromptDrivenAgent < Agent
    # [Array<Hash{Symbol => Object}>] The conversation (user prompts, responses) that happened with this agent.
    #   Each item of a conversation has the following properties:
    #   - author [String] Author of the message
    #   - at [String] UTC timestamp of the message at format YYYY-mm-dd HH:MM:SS
    #   - message [String] The message itself
    #   - question [Boolean] Is this message a question expecting a reply? Defaults to false.
    attr_reader :conversation

    # Define input artifacts contracts
    #
    # @return [Hash<Symbol, String>] Set of input artifacts description, per artifact name
    def input_artifacts_contracts
      {
        user_message: {
          description: 'User prompt',
          optional: true
        }
      }
    end

    # Define output artifacts contracts
    #
    # @return [Hash<Symbol, String>] Set of output artifacts description, per artifact name
    def output_artifacts_contracts
      {}
    end

    # Initialize a new PromptDrivenAgent with the information needed for prompts and the selected prompt rendering strategy.
    # If no name is provided, it will default to 'Executor'.
    #
    # @param role [String, nil] Agent's role, or nil for the agent's default
    # @param objective [String, nil] Agent's objective, or nil for the agent's default
    # @param system_instructions [Object, nil] Original instructions for the agent, or nil if no system instructions are needed.
    #   The kind of instructions that can be given are defined by the Instructions's constructor (see Instructions#initialize).
    # @param constraints [String, nil] Constraints to be respected, or nil for the agent's default
    # @param strategy [Module] The prompt rendering strategy
    def initialize(
      *args,
      role: nil,
      objective: nil,
      system_instructions: nil,
      constraints: nil,
      strategy: PromptRenderingStrategy::Markdown,
      **kwargs
    )
      super(*args, **kwargs)
      singleton_class.include strategy
      @role = role
      @objective = objective
      @system_instructions = system_instructions ? Instructions.new(system_instructions) : nil
      @constraints = constraints
      @conversation = []
    end

    # Execute the agent to generate some output artifacts based on some input artifacts.
    #
    # @param user_message [String] The user prompt
    # @param input_artifacts [Hash<Symbol,Object>] The input artifacts content, per artifact name
    # @return [Hash<Symbol,Object>] The output artifacts
    def run(user_message: '', **input_artifacts)
      output_artifacts = {}
      system_prompt = render_system_prompt(
        if @system_instructions
          render_instructions_list(
            @system_instructions.map do |instruction_type, instruction|
              send(:"render_instruction_#{instruction_type}", instruction)
            end
          )
        end,
        input_artifacts:
      )
      log_debug "System prompt: #{system_prompt}"
      with_system_prompt(
        system_prompt,
        input_artifacts:,
        output_artifacts:
      ) do
        converse(user_message, input_artifacts:, author: 'User')
        if respond_to?(:normalized_output_artifacts_contracts, true)
          # We know which output artifacts we are expecting.
          # Therefore check if some are missing and prompt again if that's the case.
          # TODO: Implement a max number of retries and throw an exception if it exceeds.
          loop do
            missing_artifacts = normalized_output_artifacts_contracts.reject { |artifact_name, _artifact_description| output_artifacts.key?(artifact_name) }
            break if missing_artifacts.empty?

            converse(missing_output_user_prompt(missing_artifacts))
          end
        end
      end
      output_artifacts
    end

    # Export the agent state for persistence
    #
    # @return [Object] Serialized state that can be marshalled to JSON
    def export_state
      {
        'conversation' => @conversation.map do |message|
          message.merge(at: message[:at].strftime('%F %T'))
        end
      }
    end

    # Import the agent state from persistence
    #
    # @param state [Object] Serialized state
    def import_state(state)
      @conversation = state['conversation'].map do |message|
        message = message.transform_keys(&:to_sym)
        message.merge(at: Time.parse("#{message.delete(:at)} UTC"))
      end
    end

    private

    # Prompt a user prompt and record it with its response in the conversation.
    #
    # @param user_prompt [String] The user prompt
    # @param input_artifacts [Hash<Symbol,Object>] The input artifacts content, per artifact name
    # @param author [String] Author of this message. Usually User if it is user input, but can be Orchestrator or anything else
    def converse(user_prompt, input_artifacts: {}, author: 'Orchestrator')
      rendered_user_prompt = render_user_prompt(user_prompt, input_artifacts:)
      log_debug "Rendered User prompt: #{rendered_user_prompt}"
      track_message(message: user_prompt, author:)
      response = prompt(rendered_user_prompt)
      log_debug "Raw Agent #{name} response: #{response}"
      track_message(message: response, author: "Agent#{" #{name}" if name}")
    end

    # Prepare the context for a given rendered system prompt
    #
    # @param system_prompt [Object] The rendered system prompt
    # @param input_artifacts [Hash<Symbol,Object>] The input artifacts content, per artifact name
    # @param output_artifacts [Hash<Symbol,Object>] The output artifacts to be filled by subsequent prompts, per artifact name
    # @yield Code to be executed with the context prepared
    def with_system_prompt(system_prompt, input_artifacts:, output_artifacts:)
      raise NotImplementedError, 'This method should be implemented by a PromptDrivenAgent subclass'
    end

    # Process a user prompt.
    # Prerequisites:
    # * This method is always called within a with_system_prompt block.
    #
    # @param user_prompt [Object] The rendered user prompt
    # @return [String] The output of the prompt
    def prompt(user_prompt)
      raise NotImplementedError, 'This method should be implemented by a PromptDrivenAgent subclass'
    end

    # Track a message that is part of the conversation with this agent
    #
    # @param message [String, #to_hash] The message content, as a String or an object that can be hashed
    # @param author [String] Author of the message
    # @param question [Boolean] Is this message a question expecting a reply?
    def track_message(message:, author: 'Orchestrator', question: false)
      @conversation << {
        at: Time.now.utc,
        author:,
        message: message.is_a?(String) ? message : message&.to_hash,
        question:
      }
    end
  end
end
