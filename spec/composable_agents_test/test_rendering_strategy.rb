module ComposableAgentsTest
  # Test specific PromptRenderingStrategy that records calls and returns predictable values
  module TestRenderingStrategy
    # Track method calls for verification
    def render_calls
      @render_calls ||= []
    end

    def render_instruction_text(instruction)
      render_calls << [:render_instruction_text, instruction]
      "RENDERED_TEXT: #{instruction}"
    end

    def render_instruction_ordered_list(instruction)
      render_calls << [:render_instruction_ordered_list, instruction]
      "RENDERED_LIST: #{instruction.join(', ')}"
    end

    def render_system_prompt(rendered_instructions, input_artifacts: {})
      render_calls << [:render_system_prompt, rendered_instructions, input_artifacts]
      "SYSTEM_PROMPT[#{rendered_instructions.join(' | ')}]"
    end

    def render_user_prompt(user_message, input_artifacts: {})
      render_calls << [:render_user_prompt, user_message, input_artifacts]
      "USER_PROMPT: #{user_message}"
    end

    def missing_output_user_prompt(missing_output_artifacts)
      render_calls << [:missing_output_user_prompt, missing_output_artifacts]
      "MISSING_PROMPT: #{missing_output_artifacts.map { |name, description| "#{name} (#{description})" }.join(', ')}"
    end
  end
end
