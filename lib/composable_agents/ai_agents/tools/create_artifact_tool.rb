module ComposableAgents
  module AiAgents
    module Tools
      # Tool that is used to create a new artifact's content
      class CreateArtifactTool < Agents::Tool
        include Mixins::Logger

        description 'Create an output artifact'
        param :name, type: 'string', desc: 'Artifact name'
        param :content, type: 'string', desc: 'Artifact content'

        # Constructor
        #
        # @param artifacts [Hash<Symbol,String>] The artifacts store
        def initialize(artifacts)
          super()
          @artifacts = artifacts
        end

        # Perform the tool's action.
        # This is called by ai-agents when the model requires it.
        #
        # @param tool_context [Agents::ToolContext] The tool context
        # @param name [String] The required artifact's name
        # @param content [String] The required artifact's content
        # @return [String] The tool's response
        def perform(_tool_context, name:, content:)
          @artifacts[name.to_sym] = content
          log_debug "Artifact `#{name}` written successfully."
          "Artifact `#{name}` created successfully."
        end
      end
    end
  end
end
