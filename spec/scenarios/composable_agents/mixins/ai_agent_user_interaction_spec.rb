require 'agents'

describe ComposableAgents::Mixins::AiAgentUserInteraction do
  # Stub the Agents::AgentRunner
  #
  # @param run [#call, double] The stub of the run method on the agent runner
  #   - Param agent_runner [instance_double(Agents::AgentRunner)] The agent runner stubbed instance
  def stub_agent_runner(run: double(error: nil, context: {}, output: 'Test output'))
    allow(Agents::AgentRunner).to receive(:new) do |agents|
      @agent_runner_agents = agents
      stub_agent_runner = instance_double(Agents::AgentRunner, agents:)
      allow(stub_agent_runner).to receive(:run) { run.is_a?(Proc) ? run.call(stub_agent_runner) : run }
      stub_agent_runner
    end
  end

  # [Array<Agents::Agent>] List of agents that were given to AgentRunner.new
  attr_reader :agent_runner_agents

  it 'adds AskUserTool to the agent that is passed to AgentRunner' do
    stub_agent_runner
    Class.new(ComposableAgents::AiAgents::Agent) do
      prepend ComposableAgents::Mixins::AiAgentUserInteraction
    end.new(name: 'test-agent').run
    expect(agent_runner_agents.first.tools).to include(
      an_instance_of(ComposableAgents::AiAgents::Tools::AskUserTool)
    )
  end

  it 'allows normal user interaction when the agent requires it' do
    stub_agent_runner(
      run: proc do |agent_runner|
        double(
          error: nil,
          context: {},
          output: "The answer is #{
            agent_runner
              .agents
              .first
              .tools
              .find { |tool| tool.is_a?(ComposableAgents::AiAgents::Tools::AskUserTool) }
              .execute(nil, question: 'What is the meaning of life?')
          }"
        )
      end
    )
    test_agent = Class.new(ComposableAgents::AiAgents::Agent) do
      prepend ComposableAgents::Mixins::AiAgentUserInteraction

      private

      def answer_to(question)
        "[#{question}]: 42"
      end
    end.new(name: 'test-agent', model: 'test-model')
    test_agent.run(user_instructions: 'Start interactive session')
    expect_conversation(
      test_agent.conversation,
      [
        {
          author: 'User',
          message: 'Start interactive session'
        },
        {
          author: 'Agent test-agent (AiAgent test-model)',
          message: 'What is the meaning of life?',
          question: true
        },
        {
          author: 'User',
          message: '[What is the meaning of life?]: 42'
        },
        {
          author: 'Agent test-agent (AiAgent test-model)',
          message: 'The answer is [What is the meaning of life?]: 42'
        }
      ]
    )
  end
end
