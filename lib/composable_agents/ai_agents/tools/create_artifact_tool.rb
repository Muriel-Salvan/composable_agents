module ComposableAgents
  module AiAgents
    module Tools
      # Tool that is used to create a new artifact's content
      class CreateArtifactTool < BaseTool
        # @!group Internal

        description <<~EO_DESCRIPTION
          Create an output artifact.
          Only create artifacts when the user is asking you to create an artifact named `{name}`.
          Do not create artifacts unless the user is asking you to.
        EO_DESCRIPTION
        param :name, type: 'string', desc: 'Artifact name'
        param :content, type: 'string', desc: 'Artifact content'

        # Constructor
        #
        # @param agent [PromptDrivenAgent] The agent that will receive output artifacts
        # @param logger [::Logger] Logger to be used by this tool. Any Ruby-like logger is accepted.
        #   Defaults to ComposableAgents::Logger's singleton instance.
        def initialize(agent, logger: ComposableAgents::Logger.instance)
          super(logger:)
          @agent = agent
        end

        # Perform the tool's action.
        # This is called by ai-agents when the model requires it.
        #
        # @param _tool_context [Agents::ToolContext] The tool context
        # @param name [String] The required artifact's name
        # @param content [String] The required artifact's content
        # @return [String] The tool's response
        def perform(_tool_context, name:, content:)
          @agent.save_output_artifact(name.to_sym, content)
          "Artifact `#{name}` created successfully."
        end
      end
    end
  end
end
