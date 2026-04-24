require 'agents'

describe ComposableAgents::Mixins::UserInteraction do
  let(:agent) do
    Class.new(ComposableAgents::AiAgents::Agent) do
      prepend ComposableAgents::Mixins::UserInteraction
    end.new(name: 'test-agent')
  end

  # [Array<Agents::Agent>] List of agents that were given to AgentRunner.new
  attr_reader :agent_runner_agents

  before do
    allow(Agents::AgentRunner).to receive(:new) do |agents|
      @agent_runner_agents = agents
      instance_double(Agents::AgentRunner, run: double(error: nil, context: {}, output: 'Test output'))
    end
  end

  it 'adds AskUserTool to the agent that is passed to AgentRunner' do
    agent.run
    expect(agent_runner_agents.first.tools).to include(
      an_instance_of(ComposableAgents::AiAgents::Tools::AskUserTool)
    )
  end
end
