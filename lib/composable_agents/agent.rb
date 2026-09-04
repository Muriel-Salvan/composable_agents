module ComposableAgents
  # Abstract computational unit that transforms inputs into outputs.
  # Agents may internally use LLMs, tools, or other agents.
  # Agents are stateless: they take input artifacts and return output artifacts.
  class Agent
    # @!group Public API

    # @return [String, nil] The agent name, if any.
    attr_reader :name

    # @return [Array<RunInfo>] The list of run information of this agent.
    attr_reader :runs_info

    # Constructor
    #
    # @param name [String, nil] Agent name, or nil if none
    # @param composable_agents_dir [String] Base directory where composable agents can store data
    # @param logger [::Logger] Logger to be used by this agent. Any Ruby-like logger is accepted.
    #   Defaults to ComposableAgents::Logger's singleton instance.
    #   This agent's log fields (see #log_fields) are prefixed to logged messages when the logger supports it
    #     (see ComposableAgents::Logger#tagged), and are left as-is otherwise.
    def initialize(
      name: nil,
      composable_agents_dir: '.composable_agents',
      logger: ComposableAgents::Logger.instance
    )
      @name = name
      @composable_agents_dir = composable_agents_dir
      @provided_logger = logger
      @runs_info = []
      @current_run_info = nil
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
    # @param _input_artifacts [Hash{Symbol => Object}] The input artifacts content
    # @return [Hash{Symbol => Object}] Output artifacts content
    def run(**_input_artifacts)
      @current_run_info = RunInfo.new
      @runs_info << @current_run_info
      publish_run_info(started_at: Time.now)
      {}
    end

    private

    # @return [RunInfo, nil] The current run info, or nil if no run has started yet
    attr_reader :current_run_info

    # Get the logger to be used by this agent, with this agent's log fields (see #log_fields) prefixed to messages.
    # If the provided logger does not support fields tagging, it is used as-is (fields are ignored).
    # Memoized.
    #
    # @return [::Logger] The logger to be used by this agent
    def logger
      @logger ||= @provided_logger.respond_to?(:tagged) ? @provided_logger.tagged(*log_fields) : @provided_logger
    end

    # Fields to be logged
    #
    # @return [Array<String>] Fields to log
    def log_fields
      [full_name]
    end

    # Publish run information for the current run
    #
    # @param kwargs [Hash{Symbol => Object}] Set of properties to publish
    def publish_run_info(**kwargs)
      current_run_info.publish(**kwargs)
    end
  end
end
