module ComposableAgents
  # Collection of prompt rendering strategies that can be used with PromptDrivenAgent's agents.
  # A strategy is a module that is included in the agent's singleton class when the agent is constructed
  #   (see PromptDrivenAgent#initialize).
  # Strategies must follow these rules:
  # - They must not define an #initialize method: strategies don't have any constructor parameter.
  # - A strategy that can be customized publishes public accessors on the agent, whose defaults are resolved lazily
  #   from the agent's public API, so that they can be set at any time on a constructed agent
  #   (see MarkdownHeavyFiles#artifacts_directory).
  # - They use the agent's accessors (e.g. #name, #role, #objective, #constraints, #input_artifacts,
  #   #composable_agents_dir) — including its private ones, as strategies are part of the agent — and never access
  #   its instance variables.
  module PromptRenderingStrategy
    # Render prompt as Markdown documents
    module Markdown
      # @!group Internal

      # Render an instruction of type text
      #
      # @param instruction [String] The instruction to render
      # @return [String] The rendered instruction
      def render_instruction_text(instruction)
        instruction
      end

      # Render an instruction of type ordered_list
      #
      # @param instruction [Array<String>] The instruction to render
      # @return [String] The rendered instruction
      def render_instruction_ordered_list(instruction)
        instruction.map.with_index { |step, step_idx| "# #{step_idx + 1}. #{step}" }.join("\n\n")
      end

      # Render a list of rendered instructions
      #
      # @param instructions [Array<String>] The instructions list to render
      # @return [String] The rendered instructions list
      def render_instructions_list(instructions)
        instructions.map { |instruction| Utils::Markdown.align_markdown_headers(instruction, level: 1).strip }.join("\n\n")
      end

      # Render the system prompt.
      # The following accessors are available to render the prompt:
      # - `#input_artifacts`
      # - `#role`
      # - `#objective`
      # - `#constraints`
      #
      # @param rendered_instructions [String, nil] The rendered system instructions, or nil if none
      # @return [String] The rendered system prompt
      def render_system_prompt(rendered_instructions)
        sections = []
        sections << <<~EO_SECTION if role && !role.empty?
          # Role

          #{Utils::Markdown.align_markdown_headers(role, level: 2).strip}
        EO_SECTION
        sections << <<~EO_SECTION if objective && !objective.empty?
          # Objective

          #{Utils::Markdown.align_markdown_headers(objective, level: 2).strip}
        EO_SECTION
        sections << <<~EO_SECTION if rendered_instructions && !rendered_instructions.empty?
          # Instructions

          #{Utils::Markdown.align_markdown_headers(rendered_instructions, level: 2).strip}
        EO_SECTION
        sections << <<~EO_SECTION if constraints && !constraints.empty?
          # Constraints

          #{Utils::Markdown.align_markdown_headers(constraints, level: 2).strip}
        EO_SECTION
        sections.map(&:strip).join("\n\n")
      end

      # Render the user prompt
      # The following accessors are available to render the prompt:
      # - `#role`
      # - `#objective`
      # - `#constraints`
      #
      # @param rendered_instructions [String, nil] The rendered instructions, or nil if none
      # @param input_artifacts [Hash{Symbol => Object}] The input artifacts content for which we render this prompt, per artifact name
      # @return [String] The rendered user prompt
      def render_user_prompt(rendered_instructions, input_artifacts:)
        rendered_instructions || ''
      end

      # Get the artifact reference name communicated to the assistant
      #
      # @param artifact_name [Symbol] The artifact name
      # @return [String] The artifact reference name used for the assistant
      def artifact_ref(artifact_name)
        artifact_name.to_s
      end

      # Get user instructions for missing output artifacts
      #
      # @param missing_output_artifacts [Hash{Symbol => Object}] The missing output artifacts information, per artifact name
      #   Information can contain the following attributes:
      #   - description [String] The artifact's description.
      #   - error [String, nil] An error message related to this missing artifact.
      # @return [Object] The user instructions (see Instructions#initialize)
      def missing_output_user_instructions(missing_output_artifacts)
        <<~EO_PROMPT
          Some artifacts are missing:
          #{
            (
              missing_output_artifacts.map do |artifact_name, missing_info|
                "- You must create an artifact named `#{artifact_name}`: #{missing_info[:description]}"
              end
            ).join("\n")
          }
        EO_PROMPT
      end
    end
  end
end
