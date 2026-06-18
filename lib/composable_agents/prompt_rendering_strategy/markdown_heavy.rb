module ComposableAgents
  module PromptRenderingStrategy
    # Render prompt as Markdown documents with a lot of emphasis for complex agentic systems.
    # This prompt strategy needs to be used conjointly with the ArtifactContract mixin,
    #   and on an agent that uses @context to store a JSON-serializable context.
    # This mixin also adds the following methods to be used:
    # - `.assistant_artifact_name(artifact_name) -> String` Returns the artifact name as seen by the assistant.
    #     This can be used to refer to the artifact names properly in the user or system instructions.
    module MarkdownHeavy
      include Markdown

      # Render an instruction of type ordered_list
      #
      # @param instruction [Array<String>] The instruction to render
      # @return [String] The rendered instruction
      def render_instruction_ordered_list(instruction)
        return '' if instruction.empty?

        <<~EO_INSTRUCTIONS
          Always follow all those sequential steps.

          # 1. Create the #{name} Execution Checklist (MANDATORY)

          - Before executing anything, create a checklist named #{name} Execution Checklist with all steps of these instructions.
          - Do not create files to track this checklist: keep it in your memory.
          - The #{name} Execution Checklist must include all numbered steps explicitly.
          - After completing each step of these instructions, mark the item in the #{name} Execution Checklist as completed.
          - Do not skip any item.
          - If an item cannot be executed, explicitly explain why.
          - Never mark the task as completed while any item from the #{name} Execution Checklist remains open.

          #{instruction.map.with_index { |step, step_idx| "# #{step_idx + 2}. #{Utils::Markdown.align_markdown_headers(step, level: 2).strip}" }.join("\n\n")}

          # #{instruction.size + 2}. Final Verification (MANDATORY)

          Before declaring the task complete:

          - Re-list all numbered steps from the #{name} Execution Checklist.
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
            - Each artifact is identified by a name, like `#{MarkdownHeavy.assistant_artifact_name(:plan)}`.
            - You must consider all artifacts given in the "Input artifacts" section of the user prompt.
            - All artifacts presented in the "Input artifacts" section of the user prompt provide their content in an in-line JSON document.
            #{
              input_contracts.map do |artifact_name, artifact_contract|
                name = MarkdownHeavy.assistant_artifact_name(artifact_name)
                [
                  "- The content of input artifact `#{name}` describes this: #{artifact_contract[:description]}"
                ] + (
                  if artifact_contract[:optional]
                    ["- The input artifact `#{name}` is optional and may not be given to you."]
                  else
                    ["- The input artifact `#{name}` is expected to be in the user prompt."]
                  end
                ) + [
                  "- The input artifact `#{name}` artifact content is embedded directly in the user prompt as in-line JSON. It is NOT a file. Do NOT try to open it as a file."
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
              ```json output_artifact=#{MarkdownHeavy.assistant_artifact_name(:name)}
              {artifact_content}
              ```
            - Do not create files for output artifacts: always give them inside embedded JSON in your last response.
            - Always return output artifacts that the user is asking you to provide.
            - You can return several output artifacts in your final response if needed.
            #{
              normalized_output_artifacts_contracts.map do |artifact_name, artifact_contract|
                [
                  "- The content of output artifact `#{MarkdownHeavy.assistant_artifact_name(artifact_name)}` should describe this: #{artifact_contract[:description]}",
                  <<~EO_ITEM.strip
                    - The output artifact `#{MarkdownHeavy.assistant_artifact_name(artifact_name)}` should be given in a block like this:
                      ```json output_artifact=#{MarkdownHeavy.assistant_artifact_name(artifact_name)}
                      {artifact_content}
                      ```
                  EO_ITEM
                ]
              end.flatten(1).join("\n")
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
        unless @context.empty?
          sections << <<~EO_SECTION
            # Previous sessions context

            Here is the conversation from a previous session for context:

            ```json
            #{@context.to_json}
            ```

            Continue with the task, building on the work from the session above.
          EO_SECTION
        end
        unless input_artifacts.empty?
          sections << <<~EO_SECTION.strip
            # Input artifacts

            #{
              input_artifacts.map do |artifact_name, artifact_content|
                name = MarkdownHeavy.assistant_artifact_name(artifact_name)
                <<~EO_ARTIFACT_SECTION.strip
                  ## `#{name}`

                  ```json input_artifact=#{name}
                  #{artifact_content.to_json}
                  ```
                EO_ARTIFACT_SECTION
              end.join("\n\n")
            }
          EO_SECTION
        end
        sections << <<~EO_SECTION if rendered_instructions && !rendered_instructions.empty?
          # User instructions

          #{rendered_instructions}
        EO_SECTION
        sections.map(&:strip).join("\n\n")
      end

      # Get user instructions for missing output artifacts
      #
      # @param missing_output_artifacts [Hash{Symbol => Object}] The missing output artifacts description, per artifact name
      # @return [Object] The user instructions (see Instructions#initialize)
      def missing_output_user_instructions(missing_output_artifacts)
        log_debug "[Artifact] - Asking assistant for missing output artifacts `#{missing_output_artifacts.keys.join(', ')}` to be returned in its next answer."
        <<~EO_PROMPT
          The following output artifacts are missing from your previous responses:
          #{
            missing_output_artifacts.map do |artifact_name, desc|
              "- `#{MarkdownHeavy.assistant_artifact_name(artifact_name)}`: #{desc[:description]}"
            end.join("\n")
          }

          You must provide each one of them in your next response using embedded JSON blocks like this:

          #{
            missing_output_artifacts.map do |artifact_name, _desc|
              <<~EO_MARKDOWN.strip
                ```json output_artifact=#{MarkdownHeavy.assistant_artifact_name(artifact_name)}
                {#{MarkdownHeavy.assistant_artifact_name(artifact_name)} artifact content}
                ```
              EO_MARKDOWN
            end.join("\n\n")
          }

          - You must return all those artifacts in your next response (MANDATORY).
        EO_PROMPT
      end

      # Get the artifact name communicated to the assistant
      #
      # @param artifact_name [Symbol] The artifact name
      # @return [String] The artifact name used for the assistant
      def self.assistant_artifact_name(artifact_name)
        "ARTIFACT_#{artifact_name.to_s.upcase}"
      end
    end
  end
end
