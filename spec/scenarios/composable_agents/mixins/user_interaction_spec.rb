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

  it 'tracks question and answer in agent conversation when answer_to is called' do
    test_agent = Class.new(ComposableAgents::AiAgents::Agent) do
      prepend ComposableAgents::Mixins::UserInteraction

      def answer_to(_question)
        '42'
      end
    end.new(name: 'test-agent')

    expect(test_agent.answer_to('What is the meaning of life?')).to eq('42')
    expect_conversation(
      test_agent.conversation,
      [
        {
          author: 'Agent test-agent',
          message: 'What is the meaning of life?',
          question: true
        },
        {
          author: 'User',
          message: '42'
        }
      ]
    )
  end

  it 'uses default terminal input when agent does not define custom answer_to method' do
    test_agent = Class.new(ComposableAgents::AiAgents::Agent) do
      prepend ComposableAgents::Mixins::UserInteraction
    end.new(name: 'test-agent')

    allow($stdin).to receive(:gets).and_return('This is my answer from terminal')
    allow($stdout).to receive(:puts)

    expected_answer = 'This is my answer from terminal'
    expect(test_agent.answer_to('Please answer this question?')).to eq(expected_answer)
    expect_conversation(
      test_agent.conversation,
      [
        {
          author: 'Agent test-agent',
          message: 'Please answer this question?',
          question: true
        },
        {
          author: 'User',
          message: expected_answer
        }
      ]
    )
  end
end
