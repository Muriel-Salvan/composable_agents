module ComposableAgents
  # Abstract computational unit that transforms inputs into outputs.
  # Agents may internally use LLMs, tools, or other agents.
  # Agents are stateless: they take input artifacts and return output artifacts.
  class Agent
    include Mixins::Logger

    # Constructor
    #
    # @param composable_agents_dir [String] Base directory where composable agents can store data
    def initialize(composable_agents_dir: '.composable_agents')
      @composable_agents_dir = composable_agents_dir
    end

    # Run the agent with a set of input artifacts and get the correspondong output artifacts.
    #
    # @param input_artifacts [Hash<Symbol,Object>] The input artifacts content
    # @return Hash<Symbol,Object> Output artifacts content
    def run(input_artifacts: {})
      raise NotImplementedError, 'This method should be implemented by an Agent subclass'
    end
  end
end
