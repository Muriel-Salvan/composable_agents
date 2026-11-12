require 'json'
require 'fileutils'

module ComposableAgents
  module PromptRenderingStrategy
    # Render prompt as Markdown documents with a lot of emphasis for complex agentic systems,
    # where input and output artifacts are persisted as files on disk instead of being in-lined
    # as JSON in the prompts and responses.
    # This prompt strategy needs to be used conjointly with the ArtifactContract mixin.
    # It inherits from the {MarkdownHeavy} strategy and only differs in the way artifacts are handled:
    # - Input artifacts are given to the assistant as absolute paths to files persisted on disk.
    # - Output artifacts are expected to be written by the assistant to files, at absolute paths
    #   that are then read back by {#parse_output_artifacts}.
    # This mixin also adds the following methods to be used:
    # - `#parse_output_artifacts(text)` Parses a text that comes from the agent to retrieve output artifacts from files.
    # - `#artifact_ref(artifact_name) -> String` Returns the absolute path of the artifact file as seen by the assistant.
    #     This can be used to refer to the artifact names properly in the user or system instructions.
    # The constructor accepts the following extra parameter:
    # - `artifacts_directory` [String, nil] Directory where artifacts are persisted, or nil to default to
    #   `#{composable_agents_dir}/artifacts`. Input and output artifacts are persisted in the
    #   `input` and `output` sub-directories respectively.
    module MarkdownHeavyFiles
      # @!group Internal

      include MarkdownHeavy

      # Constructor
      #
      # @param artifacts_directory [String, nil] Directory where artifacts are persisted, or nil to default to
      #   `#{composable_agents_dir}/artifacts`
      def initialize(*args, artifacts_directory: nil, **kwargs)
        super(*args, **kwargs)
        artifacts_directory ||= "#{@composable_agents_dir}/artifacts"
        @input_artifacts_directory = File.join(artifacts_directory, 'input')
        @output_artifacts_directory = File.join(artifacts_directory, 'output')
        FileUtils.mkdir_p(@input_artifacts_directory)
        FileUtils.mkdir_p(@output_artifacts_directory)
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

            The following input artifacts are persisted as files on disk. Open and read each file whenever you need the corresponding input artifact content:

            #{
              input_artifacts.map do |artifact_name, artifact_content|
                art_path = persist_input_artifact(artifact_name, artifact_content)
                <<~EO_ARTIFACT_SECTION.strip
                  ## `#{art_path}`

                  - Open and read the file `#{art_path}` whenever you need the corresponding input artifact content.
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

      # Get the artifact reference communicated to the assistant, as the absolute path of its file.
      #
      # @param artifact_name [Symbol] The artifact name
      # @return [String] The absolute path of the artifact file used for the assistant
      def artifact_ref(artifact_name)
        if normalized_input_artifacts_contracts.key?(artifact_name)
          input_artifact_path(artifact_name)
        elsif normalized_output_artifacts_contracts.key?(artifact_name)
          output_artifact_path(artifact_name)
        else
          raise "Unknown artifact: #{artifact_name}"
        end
      end

      # Get user instructions for missing output artifacts
      #
      # @param missing_output_artifacts [Hash{Symbol => Object}] The missing output artifacts information, per artifact name
      #   Information can contain the following attributes:
      #   - description [String] The artifact's description.
      #   - error [String, nil] An error message related to this missing artifact.
      # @return [Object] The user instructions (see Instructions#initialize)
      def missing_output_user_instructions(missing_output_artifacts)
        logger.debug '[Artifact] - Asking assistant for missing output artifacts ' \
          "`#{missing_output_artifacts.keys.join(', ')}` to be written as files in its next answer."
        <<~EO_PROMPT
          The following output artifacts are missing from your previous responses:
          #{
            missing_output_artifacts.map do |artifact_name, missing_info|
              ["- `#{output_artifact_path(artifact_name)}`: #{missing_info[:description]}"] +
                (missing_info[:error] ? ["  An error occurred while reading this artifact from your previous responses: #{missing_info[:error]}"] : [])
            end.flatten(1).join("\n")
          }

          You must write each one of them to its expected file path (the absolute paths given above) in your next response (MANDATORY).
        EO_PROMPT
      end

      # Parse some text to find output artifacts in the files they are persisted to.
      #
      # @param text [String] The text to be parsed
      def parse_output_artifacts(text)
        logger.debug "[Artifact] - Looking for output artifacts persisted as files (ignoring the assistant text response): #{text}"
        normalized_output_artifacts_contracts.each_key do |artifact_name|
          artifact_path = output_artifact_path(artifact_name)
          next unless File.exist?(artifact_path)

          artifact_type = normalized_output_artifacts_contracts.dig(artifact_name, :type)
          artifact_content =
            begin
              read_output_artifact(artifact_path, artifact_type)
            rescue JSON::ParserError => e
              report_error_for_output_artifact(artifact_name, e.to_s)
              nil
            end
          save_output_artifact(artifact_name, artifact_content) if artifact_content
        end
      end

      private

      # Render the input artifacts concept section of the system prompt.
      #
      # @param input_contracts [Hash{Symbol => Hash{Symbol => Object}}] The normalized input artifacts contracts
      # @return [String] The rendered input artifacts' concept and usage section
      def render_input_artifacts_system_prompt_section(input_contracts)
        <<~EO_SECTION
          # Input artifacts' concept and usage

          - Artifacts are documents that you can get as input.
          - Each input artifact is persisted as a file on disk, identified by its absolute path, like `#{input_artifact_path(input_contracts.keys.first)}`.
          - You must consider all artifacts given in the "Input artifacts" section of the user prompt.
          - The "Input artifacts" section of the user prompt gives you the absolute path of each input artifact file.
          - Open and read the file at the given absolute path whenever you need the corresponding input artifact content.
          - The file extension indicates the artifact content type: `.json` for JSON, `.md` for Markdown, `.txt` for raw text.
          #{
            input_contracts.map do |artifact_name, artifact_contract|
              art_ref = input_artifact_path(artifact_name)
              [
                "- The content of input artifact `#{art_ref}` describes this: #{artifact_contract[:description]}"
              ] + (
                if artifact_contract[:optional]
                  ["- The input artifact `#{art_ref}` is optional and may not be given to you."]
                else
                  ["- The input artifact `#{art_ref}` is expected in the user prompt."]
                end
              )
            end.flatten(1).join("\n")
          }
        EO_SECTION
      end

      # Render the output artifacts concept section of the system prompt.
      #
      # @return [String] The rendered output artifacts' concept and usage section
      def render_output_artifacts_system_prompt_section
        <<~EO_SECTION
          # Output artifacts' concept and usage

          - The user will ask you to provide some artifacts as output.
          - Each output artifact must be written to a file on disk, at the exact absolute path given in this system prompt.
          - Do NOT return output artifacts inline in your response: always write each one of them to its expected file path.
          - Always return output artifacts that the user is asking you to provide.
          - You can return several output artifacts in your responses if needed.

          Following sections enumerate all expected output artifacts.

          #{
            normalized_output_artifacts_contracts.map do |artifact_name, artifact_contract|
              art_ref = output_artifact_path(artifact_name)
              (
                [
                  "## Output artifact `#{art_ref}`",
                  '',
                  "- The content of output artifact `#{art_ref}` should describe this: #{artifact_contract[:description]}"
                ] + (
                  artifact_contract[:type] ? ["- The output artifact `#{art_ref}` content format should be #{artifact_contract[:type]}"] : []
                ) + [
                  "- Write the output artifact `#{art_ref}` to this exact absolute path. The file extension indicates the expected content type."
                ]
              ).join("\n")
            end.join("\n\n")
          }
        EO_SECTION
      end

      # Get the file extension to use for a given artifact type.
      #
      # @param artifact_type [Symbol, nil] The artifact type
      # @return [String] The corresponding file extension
      def artifact_extension(artifact_type)
        case artifact_type
        when :text then '.txt'
        when :markdown then '.md'
        when :json, nil then '.json'
        else raise "Unknown artifact type: #{artifact_type}"
        end
      end

      # Get the absolute path of an input artifact file.
      #
      # @param artifact_name [Symbol] The input artifact name
      # @return [String] The absolute path of the input artifact file
      def input_artifact_path(artifact_name)
        File.join(
          @input_artifacts_directory,
          "#{artifact_name}#{artifact_extension(normalized_input_artifacts_contracts.dig(artifact_name, :type))}"
        )
      end

      # Get the absolute path of an output artifact file.
      #
      # @param artifact_name [Symbol] The output artifact name
      # @return [String] The absolute path of the output artifact file
      def output_artifact_path(artifact_name)
        File.join(
          @output_artifacts_directory,
          "#{artifact_name}#{artifact_extension(normalized_output_artifacts_contracts.dig(artifact_name, :type))}"
        )
      end

      # Persist an input artifact to its file.
      #
      # @param artifact_name [Symbol] The input artifact name
      # @param artifact_content [Object] The input artifact content
      # @return [String] The absolute path where the artifact was persisted
      def persist_input_artifact(artifact_name, artifact_content)
        artifact_path = input_artifact_path(artifact_name)
        artifact_type = normalized_input_artifacts_contracts.dig(artifact_name, :type)
        case artifact_type
        when nil, :json
          File.write(artifact_path, JSON.pretty_generate(artifact_content))
        when :text, :markdown
          File.write(artifact_path, artifact_content)
        else
          raise "Unknown artifact type: #{artifact_type}"
        end
        artifact_path
      end

      # Read an output artifact from its file.
      #
      # @param artifact_path [String] The absolute path of the output artifact file
      # @param artifact_type [Symbol, nil] The output artifact type
      # @return [Object] The output artifact content
      def read_output_artifact(artifact_path, artifact_type)
        case artifact_type
        when nil, :json
          JSON.parse(File.read(artifact_path))
        when :text, :markdown
          File.read(artifact_path)
        else
          raise "Unknown artifact type: #{artifact_type}"
        end
      end
    end
  end
end
