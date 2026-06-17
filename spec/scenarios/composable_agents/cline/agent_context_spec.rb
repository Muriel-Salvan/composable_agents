require 'fileutils'
require 'json'

describe ComposableAgents::Cline::Agent do
  # Helper method to instantiate an agent for context testing using TestRenderingStrategyWithContext
  # to validate that the context is given properly in user prompts.
  #
  # @param kwargs [Hash] Parameters to pass to the agent constructor
  # @return [ComposableAgents::Agent] The agent
  def described_agent(**kwargs)
    described_class.new(
      composable_agents_dir: '.composable_agents_test',
      strategy: ComposableAgentsTest::TestRenderingStrategyWithContext,
      **kwargs
    )
  end

  around do |example|
    with_cline_api_key_cleared { example.call }
  end

  describe 'context' do
    it 'has an empty context at the beginning of the first run' do
      agent = described_agent
      mock_cline_for(agent)
      agent.run(user_message: 'First message')
      expect(agent.spy[:user_prompts]).to eq ['USER_PROMPT[First message and context <<<[]>>>]']
    end

    it 'accumulates context over several runs' do
      agent = described_agent
      mock_cline_for(
        agent,
        [
          { stdout: 'Assistant Output #1' },
          { stdout: 'Assistant Output #2' }
        ]
      )
      agent.run(user_message: 'First message')
      agent.run(user_message: 'Second message')
      expect(agent.spy[:user_prompts]).to eq [
        'USER_PROMPT[First message and context <<<[]>>>]',
        'USER_PROMPT[Second message and context <<<[{"role":"assistant","content":[{"type":"text","text":"Assistant Output #1"}]}]>>>]'
      ]
    end

    it 'persists the context through a JSON-serializable state' do
      agent1 = described_agent
      mock_cline_for(
        agent1,
        [
          { stdout: 'Assistant Output #1' },
          { stdout: 'Assistant Output #2' }
        ]
      )
      agent1.run(user_message: 'First message')
      agent1.run(user_message: 'Second message')
      state = agent1.export_state
      # Check that context is JSON-serializable
      expect { JSON.parse(state.to_json) }.not_to raise_error

      agent2 = described_agent
      mock_cline_for(
        agent2,
        [
          { stdout: 'Assistant Output #3' },
          { stdout: 'Assistant Output #4' }
        ]
      )
      agent2.import_state(state)
      expect(agent2.export_state).to eq state
      # Second agent's run should have the context from the first agent's runs
      agent2.run(user_message: 'Third message')
      agent2.run(user_message: 'Fourth message')
      expect(agent2.spy[:user_prompts]).to eq [
        'USER_PROMPT[First message and context <<<[]>>>]',
        'USER_PROMPT[Second message and context <<<[' \
          '{"role":"assistant","content":[{"type":"text","text":"Assistant Output #1"}]}' \
          ']>>>]',
        'USER_PROMPT[Third message and context <<<[' \
          '{"role":"assistant","content":[{"type":"text","text":"Assistant Output #1"}]},' \
          '{"role":"assistant","content":[{"type":"text","text":"Assistant Output #2"}]}' \
          ']>>>]',
        'USER_PROMPT[Fourth message and context <<<[' \
          '{"role":"assistant","content":[{"type":"text","text":"Assistant Output #1"}]},' \
          '{"role":"assistant","content":[{"type":"text","text":"Assistant Output #2"}]},' \
          '{"role":"assistant","content":[{"type":"text","text":"Assistant Output #3"}]}' \
          ']>>>]'
      ]
    end
  end
end
