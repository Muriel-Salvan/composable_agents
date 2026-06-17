shared_examples 'a prompt driven agent with artifacts contracts' do |opts|
  # Possible options for opts:
  # - new_agent [#call(example, **kwargs) -> Agent] Factory proc that initializes a new agent, decorated for testing purposes.
  #   The returned instance should provide the method `spy -> Hash{Symbol, Object}` so that the test scenarios can inspect the agent.
  #   The returned spy should have the following properties:
  #     - role [String] The agent's role
  #     - objective [String] The agent's objective
  #     - instructions [Object] The agent's normalized instructions
  #     - constraints [String] The agent's constraints
  #     - system_prompt [Object] The last rendered system prompt
  #     - user_prompts [Array<Object>] The ordered list of user prompts
  #   - Param example [RSpec::Core::ExampleGroup] The example calling this factory
  #   - Param mocked_assistant_outputs [Array<Object>, Object] List of (or single) assistant outputs to mock.
  #     An output can be one of:
  #     - [String] The text output of the assistant.
  #     - [Hash{Symbol => Object}] A more detailed structure describing the output:
  #       - text [String] The text output of the assistant (same as the String version of the output).
  #       - output_artifacts [Hash{Symbol => Object}] The output artifacts that should be mocked by the run.
  #   - Param kwargs [Hash] The parameters to be given to the agent's constructor
  #   - Return [Agent] The new agent decorated instance
  # - default_conversation_name [String] The default conversation name

  # Set default values
  opts.replace(
    {
      default_conversation_name: 'Agent'
    }.merge(opts)
  )

  # @return [Hash{Symbol, Object}] The shared examples options, now accessible to examples' helpers
  attr_reader :opts

  before do
    @opts = opts
  end

  # Instantiate a new agent, decorated for the tests
  #
  # @param mocked_assistant_outputs [Array<String>, String] List of (or single) assistant outputs to mock
  # @param kwargs [Hash] The parameters to be given to the agent's constructor
  # @return [Agent] The new agent decorated instance
  def new_agent(mocked_assistant_outputs: [], **kwargs)
    opts[:new_agent].call(self, mocked_assistant_outputs:, strategy: ComposableAgentsTest::TestRenderingStrategy, **kwargs)
  end

  describe 'retry until all output artifacts have been provided' do
    it 'does not retry when there are no expected output artifacts' do
      agent = new_agent(output_artifacts_contracts: {})
      agent.run
      expect(agent.spy[:user_prompts]).to eq ['USER_PROMPT[]']
    end

    it 'does not retry when all expected artifacts are returned on first run' do
      agent = new_agent(
        output_artifacts_contracts: { result: 'Final result', logs: 'Execution logs' },
        mocked_assistant_outputs: { output_artifacts: { result: 'ok', logs: 'logs' } }
      )
      expect(agent.run).to include(result: 'ok', logs: 'logs')
      expect(agent.spy[:user_prompts]).to eq ['USER_PROMPT[]']
    end

    it 'retries once when some artifacts are missing on first run' do
      agent = new_agent(
        output_artifacts_contracts: { result: 'Final result', logs: 'Execution logs' },
        mocked_assistant_outputs: [
          { output_artifacts: { result: 'partial' } },
          { output_artifacts: { result: 'partial', logs: 'complete' } }
        ]
      )
      expect(agent.run).to include(result: 'partial', logs: 'complete')
      expect(agent.spy[:user_prompts]).to eq [
        'USER_PROMPT[]',
        'USER_PROMPT[MISSING_PROMPT: logs (Execution logs)]'
      ]
    end

    it 'retries multiple times until all artifacts are present' do
      agent = new_agent(
        output_artifacts_contracts: { result: 'Final result', logs: 'Execution logs' },
        mocked_assistant_outputs: [
          {},
          { output_artifacts: { result: 'first' } },
          { output_artifacts: { result: 'second', logs: 'final' } }
        ]
      )
      expect(agent.run).to include(result: 'second', logs: 'final')
      expect(agent.spy[:user_prompts]).to eq [
        'USER_PROMPT[]',
        'USER_PROMPT[MISSING_PROMPT: result (Final result), logs (Execution logs)]',
        'USER_PROMPT[MISSING_PROMPT: logs (Execution logs)]'
      ]
    end
  end

  describe 'conversation' do
    it 'records retry prompts when there are output artifact contracts and 1 retry' do
      agent = new_agent(
        output_artifacts_contracts: { result: 'Final result', logs: 'Execution logs' },
        mocked_assistant_outputs: [
          { text: 'Assistant Output #1', output_artifacts: {} },
          { text: 'Assistant Output #2', output_artifacts: { result: 'complete', logs: 'success' } }
        ]
      )
      agent.run
      expect_conversation(
        agent.conversation,
        [
          { author: 'User', message: '' },
          { author: opts[:default_conversation_name], message: /Assistant Output #1/ },
          { author: 'Orchestrator', message: 'MISSING_PROMPT: result (Final result), logs (Execution logs)' },
          { author: opts[:default_conversation_name], message: /Assistant Output #2/ }
        ]
      )
    end

    it 'records retry prompts with the agent name when given' do
      agent = new_agent(
        name: 'Travel Planner',
        output_artifacts_contracts: { result: 'Final result', logs: 'Execution logs' },
        mocked_assistant_outputs: [
          { text: 'Assistant Output #1', output_artifacts: {} },
          { text: 'Assistant Output #2', output_artifacts: { result: 'complete', logs: 'success' } }
        ]
      )
      agent.run
      expect_conversation(
        agent.conversation,
        [
          { author: 'User', message: '' },
          { author: 'Agent Travel Planner', message: /Assistant Output #1/ },
          { author: 'Orchestrator', message: 'MISSING_PROMPT: result (Final result), logs (Execution logs)' },
          { author: 'Agent Travel Planner', message: /Assistant Output #2/ }
        ]
      )
    end

    it 'records all retries when there are multiple missing artifacts, several retries and runs' do
      agent = new_agent(
        output_artifacts_contracts: { result: 'Final result', logs: 'Execution logs' },
        mocked_assistant_outputs: [
          { text: 'Assistant Output #1', output_artifacts: {} },
          { text: 'Assistant Output #2', output_artifacts: { result: 'first' } },
          { text: 'Assistant Output #3', output_artifacts: { result: 'second', logs: 'final' } },
          { text: 'Assistant Output #4', output_artifacts: { result: 'second', logs: 'final' } }
        ]
      )
      agent.run
      agent.run(user_message: 'Again')
      expect_conversation(
        agent.conversation,
        [
          { author: 'User', message: '' },
          { author: opts[:default_conversation_name], message: /Assistant Output #1/ },
          { author: 'Orchestrator', message: 'MISSING_PROMPT: result (Final result), logs (Execution logs)' },
          { author: opts[:default_conversation_name], message: /Assistant Output #2/ },
          { author: 'Orchestrator', message: 'MISSING_PROMPT: logs (Execution logs)' },
          { author: opts[:default_conversation_name], message: /Assistant Output #3/ },
          { author: 'User', message: 'Again' },
          { author: opts[:default_conversation_name], message: /Assistant Output #4/ }
        ]
      )
    end
  end
end
