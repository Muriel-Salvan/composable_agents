module ComposableAgents
  module AiAgents
    module Tools
      # Tool that is used to read an artifact's content
      class GetArtifactTool < Agents::Tool
        include Mixins::Logger

        description 'Get an input artifact'
        param :name, type: 'string', desc: 'Artifact name'

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
        # @return [String] The tool's response
        def perform(_tool_context, name:)
          name_sym = name.to_sym
          if @artifacts.key?(name_sym)
            log_debug "Artifact `#{name}` read successfully."
            @artifacts[name_sym].to_s.strip
          else
            "[ERROR] No artifact named #{name}, don't call this tool with the name #{name} anymore."
          end
        end
      end
    end
  end
end
