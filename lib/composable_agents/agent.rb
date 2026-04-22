module ComposableAgents
  # Abstract computational unit that transforms inputs into outputs.
  # Agents may internally use LLMs, tools, or other agents.
  # Agents are stateless: they take input artifacts and return output artifacts.
  class Agent
    include Mixins::Logger

    attr_reader :name

    # Constructor
    #
    # @param name [String, NilClass] Agent name, or nil if none
    # @param composable_agents_dir [String] Base directory where composable agents can store data
    def initialize(
      name: nil,
      composable_agents_dir: '.composable_agents'
    )
      @name = name
      @composable_agents_dir = composable_agents_dir
    end

    # Execute the agent to generate some output artifacts based on some input artifacts.
    #
    # @param input_artifacts [Hash<Symbol,Object>] The input artifacts content
    # @return Hash<Symbol,Object> Output artifacts content
    def run(**input_artifacts)
      raise NotImplementedError, 'This method should be implemented by an Agent subclass'
    end

    private

    # Fields to be logged
    #
    # @return [Array<String>] Fields to log
    def log_fields
      @name.nil? ? [] : [@name]
    end
  end
end
