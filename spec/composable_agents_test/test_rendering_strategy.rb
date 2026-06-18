module ComposableAgentsTest
  # Test specific PromptRenderingStrategy that records calls and returns predictable values
  module TestRenderingStrategy
    def render_instruction_text(instruction)
      "RENDERED_TEXT: #{instruction}"
    end

    def render_instruction_ordered_list(instruction)
      "RENDERED_LIST: #{instruction.join(', ')}"
    end

    def render_instructions_list(instructions)
      instructions.join(' | ')
    end

    def render_system_prompt(rendered_instructions, input_artifacts: {})
      "SYSTEM_PROMPT[#{rendered_instructions}#{
        " with #{input_artifacts.map { |name, content| "#{name} (#{content})" }.join(', ')}" unless input_artifacts.empty?
      }]"
    end

    def render_user_prompt(rendered_instructions, input_artifacts: {})
      "USER_PROMPT[#{rendered_instructions}#{
        " with #{input_artifacts.map { |name, content| "#{name} (#{content})" }.join(', ')}" unless input_artifacts.empty?
      }]"
    end

    def missing_output_user_prompt(missing_output_artifacts)
      "MISSING_PROMPT: #{missing_output_artifacts.map { |name, contract| "#{name} (#{contract[:description]})" }.join(', ')}"
    end
  end
end
