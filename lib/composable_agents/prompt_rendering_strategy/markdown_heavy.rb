require 'json'

module ComposableAgents
  module PromptRenderingStrategy
    # Render prompt as Markdown documents with a lot of emphasis for complex agentic systems.
    # This prompt strategy needs to be used conjointly with the ArtifactContract mixin.
    # This mixin also adds the following methods to be used:
    # - `#parse_output_artifacts(text)` Parses a text that comes from the agent to retrieve output artifacts from it.
    # - `#artifact_ref(artifact_name) -> String` Returns the artifact name as seen by the assistant.
    #     This can be used to refer to the artifact names properly in the user or system instructions.
    module MarkdownHeavy
      # @!group Internal

      include Markdown

      # Render an instruction of type ordered_list
      #
      # @param instruction [Array<String>] The instruction to render
      # @return [String] The rendered instruction
      def render_instruction_ordered_list(instruction)
        return '' if instruction.empty?

        checklist_name = "#{name || 'Agent'} Execution Checklist"
        <<~EO_INSTRUCTIONS
          Always follow all those sequential steps.

          # 1. Create the #{checklist_name} (MANDATORY)

          - Before executing anything, create a checklist named #{checklist_name} with all steps of these instructions.
          - Do not create files to track this checklist: keep it in your memory.
          - The #{checklist_name} must include all numbered steps explicitly.
          - After completing each step of these instructions, mark the item in the #{checklist_name} as completed.
          - Do not skip any item.
          - If an item cannot be executed, explicitly explain why.
          - Never mark the task as completed while any item from the #{checklist_name} remains open.

          #{instruction.map.with_index { |step, step_idx| "# #{step_idx + 2}. #{Utils::Markdown.align_markdown_headers(step, level: 2).strip}" }.join("\n\n")}

          # #{instruction.size + 2}. Final Verification (MANDATORY)

          Before declaring the task complete:

          - Re-list all numbered steps from the #{checklist_name}.
          - Confirm each one was executed.
          - If any step was not executed, execute it now.
        EO_INSTRUCTIONS
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
        sections = [super]
        # Don't document the user instructions themselves
        input_contracts = normalized_input_artifacts_contracts.except(:user_instructions)
        unless input_contracts.empty?
          sections << <<~EO_SECTION
            # Input artifacts' concept and usage

            - Artifacts are documents that you can get as input.
            - Each artifact is identified by a name, like `#{artifact_ref(:plan)}`.
            - You must consider all artifacts given in the "Input artifacts" section of the user prompt.
            - All artifacts presented in the "Input artifacts" section of the user prompt provide their content in an in-line JSON document.
            #{
              input_contracts.map do |artifact_name, artifact_contract|
                art_ref = artifact_ref(artifact_name)
                [
                  "- The content of input artifact `#{art_ref}` describes this: #{artifact_contract[:description]}"
                ] + (
                  if artifact_contract[:optional]
                    ["- The input artifact `#{art_ref}` is optional and may not be given to you."]
                  else
                    ["- The input artifact `#{art_ref}` is expected to be in the user prompt."]
                  end
                ) + [
                  "- The input artifact `#{art_ref}` artifact content is embedded directly in the user prompt as in-line JSON. It is NOT a file. Do NOT try to open it as a file."
                ]
              end.compact.flatten(1).join("\n")
            }
          EO_SECTION
        end
        unless normalized_output_artifacts_contracts.empty?
          sections << <<~EO_SECTION
            # Output artifacts' concept and usage

            - The user will ask you to provide some artifacts as output.
            - You must always return the required artifact as a JSON document in your response, with its name in the JSON header, like this:
              ```json output_artifact=#{artifact_ref(:name)}
              {artifact_content}
              ```
            - Do not create files for output artifacts: always give them inside embedded JSON in your last response.
            - Always return output artifacts that the user is asking you to provide.
            - You can return several output artifacts in your responses if needed.

            Following sections enumerate all expected output artifacts.

            #{
              normalized_output_artifacts_contracts.map do |artifact_name, artifact_contract|
                art_ref = artifact_ref(artifact_name)
                (
                  [
                    "## Output artifact `#{art_ref}`",
                    '',
                    "- The content of output artifact `#{art_ref}` should describe this: #{artifact_contract[:description]}"
                  ] + (
                    artifact_contract[:type] ? ["- The output artifact `#{art_ref}` content format should be #{artifact_contract[:type]}"] : []
                  ) + [
                    <<~EO_ITEM.strip
                      - The output artifact `#{art_ref}` should be given in a block like this:
                      #{example_json_block(artifact_name)}
                    EO_ITEM
                  ]
                ).join("\n")
              end.join("\n\n")
            }
          EO_SECTION
        end
        sections.map(&:strip).join("\n\n")
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
        sections = []
        unless input_artifacts.empty?
          sections << <<~EO_SECTION.strip
            # Input artifacts

            #{
              input_artifacts.map do |artifact_name, artifact_content|
                art_ref = artifact_ref(artifact_name)
                <<~EO_ARTIFACT_SECTION.strip
                  ## `#{art_ref}`

                  ```json input_artifact=#{art_ref}
                  #{JSON.dump(artifact_content)}
                  ```
                EO_ARTIFACT_SECTION
              end.join("\n\n")
            }
          EO_SECTION
        end
        sections << <<~EO_SECTION if rendered_instructions && !rendered_instructions.empty?
          # User instructions

          #{Utils::Markdown.align_markdown_headers(rendered_instructions, level: 2)}
        EO_SECTION
        sections.map(&:strip).join("\n\n")
      end

      # Get user instructions for missing output artifacts
      #
      # @param missing_output_artifacts [Hash{Symbol => Object}] The missing output artifacts information, per artifact name
      #   Information can contain the following attributes:
      #   - description [String] The artifact's description.
      #   - error [String, nil] An error message related to this missing artifact.
      # @return [Object] The user instructions (see Instructions#initialize)
      def missing_output_user_instructions(missing_output_artifacts)
        log_debug "[Artifact] - Asking assistant for missing output artifacts `#{missing_output_artifacts.keys.join(', ')}` to be returned in its next answer."
        <<~EO_PROMPT
          The following output artifacts are missing from your previous responses:
          #{
            missing_output_artifacts.map do |artifact_name, missing_info|
              ["- `#{artifact_ref(artifact_name)}`: #{missing_info[:description]}"] +
                (missing_info[:error] ? ["  An error occurred while reading this artifact from your previous responses: #{missing_info[:error]}"] : [])
            end.flatten(1).join("\n")
          }

          You must provide each one of them in your next response using embedded JSON blocks like this:

          #{
            missing_output_artifacts.keys.map { |artifact_name| example_json_block(artifact_name) }.join("\n\n")
          }

          - You must return all those artifacts in your next response (MANDATORY).
        EO_PROMPT
      end

      # Get the artifact reference name communicated to the assistant
      #
      # @param artifact_name [Symbol] The artifact name
      # @return [String] The artifact reference name used for the assistant
      def artifact_ref(artifact_name)
        "ARTIFACT_#{artifact_name.to_s.upcase}"
      end

      # Parse some text to find output artifacts in it.
      #
      # @param text [String] The text to be parsed
      def parse_output_artifacts(text)
        # Scan for JSON documents with artifact markers in the format:
        # ```json output_artifact=ARTIFACT_<NAME>
        # {artifact_content}
        # ```
        text.scan(/```json\s+output_artifact=(\S+)\n(.*?)```(?=\n|\z)/m) do
          art_ref = Regexp.last_match(1)
          content = Regexp.last_match(2).strip
          # Convert the assistant artifact name (e.g. ARTIFACT_PLAN) back to a symbol (e.g. :plan)
          artifact_name = (art_ref.start_with?('ARTIFACT_') ? art_ref.sub(/^ARTIFACT_/, '') : art_ref).downcase.to_sym
          artifact_json_content = nil
          begin
            artifact_json_content = JSON.parse(content)
          rescue JSON::ParserError => e
            report_error_for_output_artifact(artifact_name, e.to_s)
            next
          end
          # Use the type info to better parse the JSON into the real artifact content
          artifact_type = normalized_output_artifacts_contracts.dig(artifact_name, :type)
          artifact_content =
            case artifact_type
            when nil, :json
              artifact_json_content
            when :text
              if artifact_json_content.key?('text')
                if artifact_json_content['text'].is_a?(String)
                  artifact_json_content['text']
                else
                  report_error_for_output_artifact(
                    artifact_name,
                    'Wrong format for artifact content in key "text": ' \
                      "expecting a raw String but got #{artifact_json_content['text'].class.name} instead."
                  )
                  nil
                end
              else
                report_error_for_output_artifact(
                  artifact_name,
                  'Missing required key "text" containing the artifact text content in the JSON artifact response.'
                )
                nil
              end
            when :markdown
              if artifact_json_content.key?('markdown')
                if artifact_json_content['markdown'].is_a?(String)
                  artifact_json_content['markdown']
                else
                  report_error_for_output_artifact(
                    artifact_name,
                    'Wrong format for artifact content in key "markdown": ' \
                      "expecting a Markdown string but got #{artifact_json_content['markdown'].class.name} instead."
                  )
                  nil
                end
              else
                report_error_for_output_artifact(
                  artifact_name,
                  'Missing required key "markdown" containing the artifact Markdown content in the JSON artifact response.'
                )
                nil
              end
            else
              raise "Unknown artifact type: #{artifact_type}"
            end
          save_output_artifact(artifact_name, artifact_content) if artifact_content
        end
      end

      private

      # Provide a Markdown example of a JSON block for a given output artifact
      #
      # @param artifact_name [Symbol] The output artifact name
      # @return [String] Corresponding Markdown example
      def example_json_block(artifact_name)
        art_ref = artifact_ref(artifact_name)
        artifact_type = normalized_output_artifacts_contracts.dig(artifact_name, :type)
        <<~EO_MARKDOWN.strip
          ```json output_artifact=#{art_ref}
          #{
            case artifact_type
            when nil
              "#{art_ref}_content"
            when :text
              "{\"text\":\"#{art_ref}_raw_text_content\"}"
            when :markdown
              "{\"markdown\":\"#{art_ref}_markdown_content\"}"
            when :json
              "{#{art_ref}_json_content}"
            else
              raise "Unknown artifact type: #{artifact_type}"
            end
          }
          ```
        EO_MARKDOWN
      end
    end
  end
end
