require 'commonmarker'

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

            #{align_markdown_headers(@role, level: 2).strip}
          EO_SECTION
        ]
        # sections = []
        sections << <<~EO_SECTION unless @objective.empty?
          # Objective

          #{align_markdown_headers(@objective, level: 2).strip}
        EO_SECTION
        sections << <<~EO_SECTION
          # Instructions

          #{rendered_instructions.map { |instructions| align_markdown_headers(instructions, level: 2).strip }.join("\n\n")}
        EO_SECTION
        sections << <<~EO_SECTION unless @constraints.empty?
          # Constraints

          #{align_markdown_headers(@constraints, level: 2).strip}
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

      # Render the user prompt for missing output artifacts
      #
      # @param missing_output_artifacts [Hash<Symbol,Object>] The missing output artifacts description, per artifact name
      # @return [Object] The rendered user prompt
      def render_missing_output_user_prompt(missing_output_artifacts)
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

      private

      # Align markdown headers in a String to a given level.
      # This method parses the String as a markdown document, sees the minimum current header level,
      # and changes it while preserving the structure and hierarchy so that this min level is equal to `level`.
      #
      # Parameters::
      # * *markdown* (String): The markdown content to align
      # * *level* (Integer): The target level for the minimum header [default: 2]
      # Result::
      # * String: The aligned markdown content
      def align_markdown_headers(markdown, level: 2)
        doc = Commonmarker.parse(markdown)
        min_level = find_minimum_header_level(doc)
        return markdown if min_level.nil? || min_level == level

        adjust_header_levels(doc, level - min_level)
        doc.to_commonmark
      end

      # Find the minimum header level in a CommonMarker document
      #
      # Parameters::
      # * *doc* (CommonMarker::Document): The parsed CommonMarker document
      # Result::
      # * Integer or nil: The minimum header level found, or nil if no headers exist
      def find_minimum_header_level(doc)
        min_level = nil
        doc.walk do |node|
          if node.type == :heading
            current_level = node.header_level
            min_level = current_level if min_level.nil? || current_level < min_level
          end
        end
        min_level
      end

      # Adjust header levels in a CommonMarker document by a given difference
      #
      # Parameters::
      # * *doc* (CommonMarker::Document): The parsed CommonMarker document
      # * *level_diff* (Integer): The difference to add to each header level
      def adjust_header_levels(doc, level_diff)
        doc.walk do |node|
          node.header_level = node.header_level + level_diff if node.type == :heading
        end
      end
    end
  end
end
