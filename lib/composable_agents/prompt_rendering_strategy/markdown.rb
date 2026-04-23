module ComposableAgents
  module PromptRenderingStrategy
    # Render prompt as Markdown documents
    module Markdown
      # Render an instruction of type text
      #
      # @param instruction [String] The instruction to render
      # @return [Object] The rendered instruction
      def render_instruction_text(instruction)
        instruction
      end

      # Render an instruction of type ordered_list
      #
      # @param instruction [Array<String>] The instruction to render
      # @return [Object] The rendered instruction
      def render_instruction_ordered_list(instruction)
        instruction.map.with_index { |step, step_idx| "# #{step_idx + 1}. #{step}" }.join("\n\n")
      end

      # Render the system prompt
      #
      # @param rendered_instructions [Array<Object>] The rendered instructions
      # @param input_artifacts [Hash<Symbol,Object>] The input artifacts content, per artifact name
      # @return [Object] The rendered system prompt
      def render_system_prompt(rendered_instructions, input_artifacts: {})
        sections = [
          <<~EO_SECTION
            # Role

            #{Utils::Markdown.align_markdown_headers(@role, level: 2).strip}
          EO_SECTION
        ]
        # sections = []
        sections << <<~EO_SECTION unless @objective.empty?
          # Objective

          #{Utils::Markdown.align_markdown_headers(@objective, level: 2).strip}
        EO_SECTION
        sections << <<~EO_SECTION
          # Instructions

          #{rendered_instructions.map { |instructions| Utils::Markdown.align_markdown_headers(instructions, level: 2).strip }.join("\n\n")}
        EO_SECTION
        sections << <<~EO_SECTION unless @constraints.empty?
          # Constraints

          #{Utils::Markdown.align_markdown_headers(@constraints, level: 2).strip}
        EO_SECTION
        sections.map(&:strip).join("\n\n")
      end

      # Render the user prompt
      #
      # @param user_message [String] The user message
      # @param input_artifacts [Hash<Symbol,Object>] The input artifacts content, per artifact name
      # @return [Object] The rendered user prompt
      def render_user_prompt(user_message, input_artifacts: {})
        user_message
      end

      # Get a user prompt for missing output artifacts
      #
      # @param missing_output_artifacts [Hash<Symbol,Object>] The missing output artifacts description, per artifact name
      # @return [Object] The user prompt
      def missing_output_user_prompt(missing_output_artifacts)
        <<~EO_PROMPT
          Some artifacts are missing:
          #{
            (
              missing_output_artifacts.map do |name, description|
                "- You must create an artifact named `#{name}`: #{description}"
              end
            ).join("\n")
          }
        EO_PROMPT
      end
    end
  end
end
