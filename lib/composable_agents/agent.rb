module ComposableAgents
  # Abstract computational unit that transforms inputs into outputs.
  # Agents may internally use LLMs, tools, or other agents.
  # Agents are stateless: they take input artifacts and return output artifacts.
  class Agent
    include Mixins::Logger

    # @return [String, nil] The agent name, if any
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

    # Return the full name of the agent.
    # This method is intended to be overridden by subclasses to give better full names, tailored to the kind of agent.
    # The full name can be used in logs and traces to better identify the agent.
    #
    # @return [String] The agent's full name
    def full_name
      "#{name || 'Unnamed'}#{" (#{self.class.name.split('::').last})" if self.class != Agent && self.class.name}"
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
