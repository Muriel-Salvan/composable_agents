module ComposableAgents
  # Agent implementation that uses a prompt rendering strategy to render prompts for a prompting engine.
  # The following prompts are considered:
  # * A system prompt, that defines the Agent's behaviour, or persona.
  # * User prompts, that are used as user inputs guiding the agent.
  # * Retry prompts, used to tell the Agent that the task at hand is still incomplete and needs more work.
  #     For example when an artifact has not been created, and the agent needs to try it again.
  #
  # Prompt rendering strategies are useful because different prompt-driven agents would benefit from different
  #   prompt formats or structures (JSON, Markdown, explicit ordered lists, in-lining artifacts' contents without tools...).
  # This agent autmatically records non-rendered conversation (prompts + outputs) in a `conversation` output artifact.
  class PromptDrivenAgent < Agent
    # Initialize a new PromptDrivenAgent with the information needed for prompts and the selected prompt rendering strategy.
    # If no name is provided, it will default to 'Executor'.
    #
    # @param role [String, NilClass] Agent's role, or nil for default
    # @param objective [String] Agent's objective
    # @param instructions [Object] Original instructions given to the agent
    #   Here are the possible kinds of instructions:
    #   * [Array<Object>] List of instruction descriptions that should be appended
    #   * [Object] Individual instruction description.
    #   An individual instruction can be one of the following:
    #     * [Hash<Symbol,Object>] A structure describing the instructions
    #     * [String] Direct instructions to be used (equivalent to { text: instructions })
    #     Here is the list of keys that can define different instructions:
    #       * text [String] The instructions are given as text directly.
    #       * ordered_list [Array<String>] The instructions are a precise list of steps to perform.
    #       Several keys can be used in the same Hash, and they will be treated in the order of the Hash.
    # @param constraints [String] Constraints to be respected
    # @param strategy [Module] The prompt rendering strategy
    def initialize(
      *args,
      role: nil,
      objective: '',
      instructions: '',
      constraints: '',
      strategy: PromptRenderingStrategy::Markdown,
      **kwargs
    )
      super(*args, **kwargs)
      singleton_class.include strategy
      @name ||= 'Executor'
      @role = role || "You are a #{@name} agent"
      @objective = objective
      # Normalize instructions to [Array<Hash<Symbol, Object>>]. Each instruction can contain the following keys:
      # * text [String] The instructions are given as text directly.
      # * ordered_list [Array<String>] The instructions are a precise list of steps to perform.
      # Several keys can be used in the same Hash, and they will be treated in the order of the Hash.
      @instructions = (
        instructions.is_a?(Array) ? instructions : [instructions]
      ).map { |instruction_desc| instruction_desc.is_a?(Hash) ? instruction_desc : { text: instruction_desc } }
      @constraints = constraints
    end

    # Execute the agent to generate some output artifacts based on some input artifacts.
    #
    # @param input_artifacts [Hash<Symbol,Object>] The input artifacts content, per artifact name
    # @return [Hash<Symbol,Object>] The output artifacts
    def run(**input_artifacts)
      output_artifacts = {}
      system_prompt = render_system_prompt(
        (
          @instructions.map do |instruction_desc|
            instruction_desc.map do |instruction_type, instruction|
              send(:"render_instruction_#{instruction_type}", instruction)
            end
          end
        ).flatten(1),
        input_artifacts:
      )
      log_debug "System prompt: #{system_prompt}"
      with_system_prompt(
        system_prompt,
        input_artifacts:,
        output_artifacts:
      ) do
        converse(input_artifacts.fetch(:user_message, ''), input_artifacts:, output_artifacts:)
        if respond_to?(:output_artifacts_contracts, true)
          # We know which output artifacts we are expecting.
          # Therefore check if some are missing and prompt again if that's the case.
          # TODO: Implement a max number of retries and throw an exception if it exceeds.
          loop do
            missing_artifacts = output_artifacts_contracts.reject { |artifact_name, _artifact_description| output_artifacts.key?(artifact_name) }
            break if missing_artifacts.empty?

            converse(missing_output_user_prompt(missing_artifacts), input_artifacts:, output_artifacts:)
          end
        end
      end
      output_artifacts
    end

    private

    # Prompt a user prompt and record it with its response in the conversation output artifact.
    #
    # @param user_prompt [String] The user prompt
    # @param input_artifacts [Hash<Symbol,Object>] The input artifacts content, per artifact name
    # @param output_artifacts [Hash<Symbol,Object>] The output artifacts to be filled for the conversation
    def converse(user_prompt, input_artifacts:, output_artifacts:)
      rendered_user_prompt = render_user_prompt(user_prompt, input_artifacts:)
      log_debug "Rendered User prompt: #{rendered_user_prompt}"
      output_artifacts[:conversation] ||= []
      output_artifacts[:conversation] << {
        'author' => 'User',
        'at' => Time.now.utc.strftime('%F %T'),
        'message' => user_prompt
      }
      response = prompt(rendered_user_prompt)
      log_debug "Raw Agent #{name} response: #{response}"
      output_artifacts[:conversation] << {
        'author' => "Agent #{name}",
        'at' => Time.now.utc.strftime('%F %T'),
        'message' => response
      }
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
  end
end
