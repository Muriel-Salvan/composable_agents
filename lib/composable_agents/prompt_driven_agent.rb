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
    # @return [String, nil] Agent's role, or nil for the agent's default
    attr_accessor :role

    # @return [String, nil] Agent's objective, or nil for the agent's default
    attr_accessor :objective

    # @return [Object, nil] Agent's original instructions, or nil if no system instructions are needed (see Instructions#initialize)
    attr_accessor :system_instructions

    # @return [String, nil] Constraints to be respected, or nil for the agent's default
    attr_accessor :constraints

    # @return [Array<Hash{Symbol => Object}>] The conversation (user prompts, responses) that happened with this agent.
    #   Each item of a conversation has the following properties:
    #   - author [String] Author of the message
    #   - at [String] UTC timestamp of the message at format YYYY-mm-dd HH:MM:SS
    #   - message [String] The message itself
    #   - question [Boolean] Is this message a question expecting a reply? Defaults to false.
    attr_reader :conversation

    # Define input artifacts contracts
    #
    # @return [Hash{Symbol => Object}] Set of input artifacts description, per artifact name
    def input_artifacts_contracts
      {
        user_instructions: {
          description: 'User instructions',
          optional: true
        }
      }
    end

    # Define output artifacts contracts
    #
    # @return [Hash{Symbol => Object}>] Set of output artifacts description, per artifact name
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
      @system_instructions = system_instructions
      @constraints = constraints
      @conversation = []
    end

    # Execute the agent to generate some output artifacts based on some input artifacts.
    #
    # @param user_instructions [Object, nil] Instructions for the user prompt, that will be rendered.
    #   The kind of instructions that can be given are defined by the Instructions's constructor (see Instructions#initialize).
    # @param input_artifacts [Hash{Symbol => Object}] The input artifacts content, per artifact name
    # @return [Hash{Symbol => Object}] The output artifacts
    def run(user_instructions: nil, **input_artifacts)
      @input_artifacts = input_artifacts
      @output_artifacts = {}
      @output_artifacts_errors = {}
      @system_prompt = render_system_prompt(render_instructions(@system_instructions))
      log_debug "System prompt: #{@system_prompt}"
      converse(user_instructions, input_artifacts: @input_artifacts, author: 'User')
      if respond_to?(:normalized_output_artifacts_contracts, true)
        # We know which output artifacts we are expecting.
        # Therefore check if some are missing and prompt again if that's the case.
        # TODO: Implement a max number of retries and throw an exception if it exceeds.
        loop do
          missing_artifacts = normalized_output_artifacts_contracts
            .reject { |artifact_name, _artifact_description| @output_artifacts.key?(artifact_name) }
            .to_h do |artifact_name, artifact_description|
              [
                artifact_name,
                artifact_description.merge(@output_artifacts_errors[artifact_name] ? { error: @output_artifacts_errors[artifact_name] } : {})
              ]
            end
          break if missing_artifacts.empty?

          converse(missing_output_user_instructions(missing_artifacts))
        end
      end
      @output_artifacts
    end

    # Export the agent state for persistence
    #
    # @return [Object] Serialized state that can be marshalled to JSON
    def export_state
      deep_transform_keys(
        {
          conversation: @conversation.map do |message|
            message.merge(at: message[:at].strftime('%F %T'))
          end
        },
        &:to_s
      )
    end

    # Import the agent state from persistence
    #
    # @param state [Object] Serialized state
    def import_state(state)
      @conversation = deep_transform_keys(state, &:to_sym)[:conversation].map do |message|
        message.merge(at: Time.parse("#{message.delete(:at)} UTC"))
      end
    end

    # Save an output artifact.
    # This method can be used at anytime while prompting, when the agent is able to produce an output artifact.
    #
    # @param artifact_name [Symbol] Output artifact name
    # @param content [Object] Output artifact content
    def save_output_artifact(artifact_name, content)
      @output_artifacts[artifact_name] = content
      @output_artifacts_errors.delete(artifact_name)
      log_debug "[Artifact] - Received output artifact #{artifact_name}"
    end

    # Report an error on an output artifact.
    # This method can be used at anytime while prompting, when the agent is unable to produce an output artifact
    #   because of an error that should be communicated back to the agent.
    # Make sure previous versions of this output artifact are removed to not store wrong versions by mistake.
    #
    # @param artifact_name [Symbol] Output artifact name
    # @param error [String] Error associated to this output artifact
    def report_error_for_output_artifact(artifact_name, error)
      @output_artifacts.delete(artifact_name)
      @output_artifacts_errors[artifact_name] = error
      # TODO: Make this as a warning message
      log_debug "[Artifact] - Should have received content for output artifact `#{artifact_name}` " \
        "but the following error occurred: #{error}"
    end

    private

    # Render instructions using the prompt rendering strategy.
    # Returns nil if instructions is nil.
    #
    # @param instructions [Object, nil] Instructions to render, or nil if none (see Instructions#initialize).
    # @return [String, nil] The rendered instructions, or nil if none
    def render_instructions(instructions)
      return nil unless instructions

      render_instructions_list(
        Instructions.new(instructions).map do |instruction_type, instruction|
          send(:"render_instruction_#{instruction_type}", instruction)
        end
      )
    end

    # Prompt a user prompt and record it with its response in the conversation.
    #
    # @param instructions [Object, nil] The instructions for the user prompt (see Instructions#initialize), or nil if none
    # @param input_artifacts [Hash{Symbol => Object}] The input artifacts content, per artifact name
    # @param author [String] Author of this message. Usually User if it is user input, but can be Orchestrator or anything else
    def converse(instructions, input_artifacts: {}, author: 'Orchestrator')
      rendered_instructions = render_instructions(instructions)
      rendered_user_prompt = render_user_prompt(rendered_instructions, input_artifacts:)
      log_debug "Rendered User prompt: #{rendered_user_prompt}"
      track_message(message: rendered_instructions, author:)
      response = prompt(rendered_user_prompt)
      log_debug "Raw Agent #{full_name} response: #{response}"
      track_message(message: response, author: "Agent #{full_name}")
    end

    # Process a user prompt.
    #
    # @param user_prompt [String] The rendered user prompt
    # @return [String] The output of the prompt
    def prompt(user_prompt)
      raise NotImplementedError, 'This method should be implemented by a PromptDrivenAgent subclass'
    end

    # Track a message that is part of the conversation with this agent
    #
    # @param message [String, #to_hash, nil] The message content, as a String or an object that can be hashed, or nil if none.
    # @param author [String] Author of the message.
    # @param question [Boolean] Is this message a question expecting a reply?
    def track_message(message:, author: 'Orchestrator', question: false)
      @conversation << {
        at: Time.now.utc,
        author:,
        message: message.is_a?(String) ? message : message&.to_hash,
        question:
      }
    end

    # Apply a deep nested transformation on a Hash's keys.
    # Traverse nested arrays and hashes.
    #
    # @param obj [Object] The source object to transform (could be Hash, Array, or any other object).
    # @yield [#call(key) -> Object] Transformation operation
    # @yieldparam key [Object] Source key to be transformed
    # @yieldreturn [Object] Transformed key
    # @return [Object] The transformed object
    def deep_transform_keys(obj, &)
      case obj
      when Hash
        obj.each_with_object({}) { |(key, value), result| result[yield(key)] = deep_transform_keys(value, &) }
      when Array
        obj.map { |value| deep_transform_keys(value, &) }
      else
        obj
      end
    end
  end
end
