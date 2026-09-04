module ComposableAgents
  module AiAgents
    module Tools
      # Tool that is used to read an artifact's content
      class GetArtifactTool < BaseTool
        # @!group Internal

        description 'Get an input artifact'
        param :name, type: 'string', desc: 'Artifact name'

        # Constructor
        #
        # @param artifacts [Hash{Symbol => Object}>] The artifacts store
        # @param logger [::Logger] Logger to be used by this tool. Any Ruby-like logger is accepted.
        #   Defaults to ComposableAgents::Logger's singleton instance.
        def initialize(artifacts, logger: ComposableAgents::Logger.instance)
          super(logger:)
          @artifacts = artifacts
        end

        # Perform the tool's action.
        # This is called by ai-agents when the model requires it.
        #
        # @param _tool_context [Agents::ToolContext] The tool context
        # @param name [String] The required artifact's name
        # @return [String] The tool's response
        def perform(_tool_context, name:)
          name_sym = name.to_sym
          if @artifacts.key?(name_sym)
            @logger.debug "Artifact `#{name}` read successfully."
            @artifacts[name_sym].to_s.strip
          else
            "[ERROR] No artifact named #{name}, don't call this tool with the name #{name} anymore."
          end
        end
      end
    end
  end
end
