require 'json'

module ComposableAgentsTest
  # Test specific PromptRenderingStrategy that records calls and returns predictable values
  module TestRenderingStrategy
    # Render an instruction of type text
    #
    # @param instruction [String] The instruction to render
    # @return [String] The rendered instruction
    def render_instruction_text(instruction)
      "RENDERED_TEXT: #{instruction}"
    end

    # Render an instruction of type ordered_list
    #
    # @param instruction [Array<String>] The instruction to render
    # @return [String] The rendered instruction
    def render_instruction_ordered_list(instruction)
      "RENDERED_LIST: #{instruction.join(', ')}"
    end

    # Render a list of rendered instructions
    #
    # @param instructions [Array<String>] The instructions list to render
    # @return [String] The rendered instructions list
    def render_instructions_list(instructions)
      instructions.join(' | ')
    end

    # Render the system prompt
    # The following instance variables are accessible to render the prompt:
    # - `@input_artifacts`
    # - `@role`
    # - `@objective`
    # - `@constraints`
    #
    # @param rendered_instructions [String, nil] The rendered system instructions, or nil if none
    # @return [String] The rendered system prompt
    def render_system_prompt(rendered_instructions)
      "SYSTEM_PROMPT[#{rendered_instructions}#{
        " with #{@input_artifacts.map { |art_name, content| "#{art_name} (#{content})" }.join(', ')}" unless @input_artifacts.empty?
      }]"
    end

    # Render the user prompt
    # The following instance variables are accessible to render the prompt:
    # - `@role`
    # - `@objective`
    # - `@constraints`
    #
    # @param rendered_instructions [String, nil] The rendered instructions, or nil if none
    # @param input_artifacts [Hash{Symbol => Object}] The input artifacts content for which we render this prompt, per artifact name
    # @return [String] The rendered user prompt
    def render_user_prompt(rendered_instructions, input_artifacts:)
      "USER_PROMPT[#{rendered_instructions}#{
        " with #{input_artifacts.map { |art_name, content| "#{art_name} (#{content})" }.join(', ')}" unless input_artifacts.empty?
      }]"
    end

    # Get the artifact reference name communicated to the assistant
    #
    # @param artifact_name [Symbol] The artifact name
    # @return [String] The artifact reference name used for the assistant
    def artifact_ref(artifact_name)
      "ARTIFACT_#{artifact_name.to_s.upcase}"
    end

    # Get user instructions for missing output artifacts
    #
    # @param missing_output_artifacts [Hash{Symbol => Object}] The missing output artifacts information, per artifact name
    #   Information can contain the following attributes:
    #   - description [String] The artifact's description.
    #   - error [String, nil] An error message related to this missing artifact.
    # @return [Object] The user instructions (see Instructions#initialize)
    def missing_output_user_instructions(missing_output_artifacts)
      "MISSING_PROMPT: #{
        missing_output_artifacts.map do |artifact_name, missing_info|
          "#{artifact_name} (#{missing_info[:description]})#{" (Error: #{missing_info[:error]})" if missing_info[:error]}"
        end.join(', ')
      }"
    end

    # Parse some text to find output artifacts in it.
    #
    # @param text [String] The text to be parsed
    def parse_output_artifacts(text)
      # This method is used when the test strategy is used with some specific agents, like the Cline::Agent one.
      # It detects Markdown JSON artifacts named ARTIFACT_.*.
      text.scan(/```json\s+output_artifact=(\S+)\n(.*?)```(?=\n|\z)/m) do
        art_ref = Regexp.last_match(1)
        content = Regexp.last_match(2).strip
        artifact_name = art_ref.gsub('ARTIFACT_', '').downcase.to_sym
        json_content =
          begin
            JSON.parse(content)
          rescue JSON::ParserError => e
            report_error_for_output_artifact(artifact_name, e)
          end
        save_output_artifact(artifact_name, json_content) if json_content
      end
    end
  end
end
