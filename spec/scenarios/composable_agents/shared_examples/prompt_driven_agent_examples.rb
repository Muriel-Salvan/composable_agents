require 'json'

shared_examples 'a prompt driven agent' do |opts|
  # Possible options for opts:
  # - new_agent [#call(example, **kwargs) -> Agent] Factory proc that initializes a new agent, decorated for testing purposes.
  #   The returned instance should provide the method `spy -> Hash{Symbol, Object}` so that the test scenarios can inspect the agent.
  #   The returned spy should have the following properties:
  #     - role [String, nil] The agent's role
  #     - objective [String, nil] The agent's objective
  #     - instructions [Object, nil] The agent's normalized instructions
  #     - constraints [String, nil] The agent's constraints
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
  # - contracts [Boolean] Is the agent using artifacts contracts? Defaults to `false`.
  # - default_conversation_name [String] The default conversation name

  # Set default values
  opts.replace(
    {
      contracts: false,
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

  describe '#initialize' do
    it 'is initialized with parameters defining a prompt-driven agent' do
      agent_spy = new_agent(
        role: 'Test Executor',
        objective: 'Execute tests',
        instructions: 'Read and run test files',
        constraints: 'Don\'t write files'
      ).spy
      expect(agent_spy[:role]).to eq 'Test Executor'
      expect(agent_spy[:objective]).to eq 'Execute tests'
      expect(agent_spy[:instructions]).to eq [{ text: 'Read and run test files' }]
      expect(agent_spy[:constraints]).to eq 'Don\'t write files'
    end
  end

  describe 'the system prompt' do
    describe 'the rendering of instructions' do
      {
        'single String': {
          instructions: 'Single instruction',
          system_prompt: 'RENDERED_TEXT: Single instruction'
        },
        'single Hash with :text key': {
          instructions: { text: 'Hash text instruction' },
          system_prompt: 'RENDERED_TEXT: Hash text instruction'
        },
        'single Hash with :ordered_list key': {
          instructions: { ordered_list: ['Step 1', 'Step 2', 'Step 3'] },
          system_prompt: 'RENDERED_LIST: Step 1, Step 2, Step 3'
        },
        'Hash with multiple types': {
          instructions: {
            text: 'Do this task:',
            ordered_list: ['First step', 'Second step']
          },
          system_prompt: 'RENDERED_TEXT: Do this task: | RENDERED_LIST: First step, Second step'
        },
        'Array of mixed types': {
          instructions: [
            'First instruction',
            { text: 'Second instruction' },
            { ordered_list: ['Step A', 'Step B'] }
          ],
          system_prompt: 'RENDERED_TEXT: First instruction | RENDERED_TEXT: Second instruction | RENDERED_LIST: Step A, Step B'
        }
      }.each do |description, test_data|
        context "when handling #{description}" do
          it 'sets the system prompt without artifacts' do
            agent = new_agent(instructions: test_data[:instructions])
            agent.run
            expect(agent.spy[:system_prompt]).to eq "SYSTEM_PROMPT[#{test_data[:system_prompt]}]"
          end

          it 'does not use the user message in the system prompt' do
            agent = new_agent(instructions: test_data[:instructions])
            agent.run(user_message: 'Do this')
            expect(agent.spy[:system_prompt]).to eq "SYSTEM_PROMPT[#{test_data[:system_prompt]}]"
          end

          it 'uses the input artifacts in the system prompt' do
            agent = new_agent(
              **{
                instructions: test_data[:instructions],
                input_artifacts_contracts: opts[:contracts] ? { test_artifact: 'Description' } : nil
              }.compact
            )
            agent.run(user_message: 'Do this', test_artifact: 'Content')
            expect(agent.spy[:system_prompt]).to eq "SYSTEM_PROMPT[#{test_data[:system_prompt]} with test_artifact (Content)]"
          end
        end
      end
    end
  end

  describe 'the user prompt' do
    let(:agent) { new_agent(mocked_assistant_outputs: 'Assistant Output') }

    it 'sends the user message in the user prompt' do
      agent.run(user_message: 'You must do this')
      expect(agent.spy[:user_prompts]).to eq ['USER_PROMPT[You must do this]']
    end

    it 'handles missing user messages and no input artifact' do
      agent.run
      expect(agent.spy[:user_prompts]).to eq ['USER_PROMPT[]']
    end

    context 'with input artifacts' do
      let(:agent) do
        new_agent(
          **{
            input_artifacts_contracts: opts[:contracts] ? { requirements: 'Features specs' } : nil
          }.compact
        )
      end

      it 'sends the artifacts in the user prompt' do
        agent.run(user_message: 'You must do this', requirements: 'Feature specs')
        expect(agent.spy[:user_prompts]).to eq ['USER_PROMPT[You must do this with requirements (Feature specs)]']
      end

      it 'handles missing user messages' do
        agent.run(requirements: 'Feature specs')
        expect(agent.spy[:user_prompts]).to eq ['USER_PROMPT[ with requirements (Feature specs)]']
      end
    end
  end

  describe 'conversation' do
    let(:agent) do
      new_agent(
        mocked_assistant_outputs: [
          'Assistant Output #1',
          'Assistant Output #2',
          'Assistant Output #3'
        ]
      )
    end

    it 'records the prompt' do
      agent.run(user_message: 'Test user prompt')
      expect_conversation(
        agent.conversation,
        [
          { author: 'User', message: 'Test user prompt' },
          { author: opts[:default_conversation_name], message: 'Assistant Output #1' }
        ]
      )
    end

    it 'records the prompt using a specific agent name' do
      named_agent = new_agent(
        mocked_assistant_outputs: ['Assistant Output #1'],
        name: 'Test Assistant'
      )
      named_agent.run(user_message: 'Test user prompt')
      expect_conversation(
        named_agent.conversation,
        [
          { author: 'User', message: 'Test user prompt' },
          { author: 'Agent Test Assistant', message: 'Assistant Output #1' }
        ]
      )
    end

    it 'records the prompts of several runs' do
      agent.run(user_message: 'Test user prompt')
      agent.run(user_message: 'Test another user prompt')
      agent.run(user_message: 'What?')
      expect_conversation(
        agent.conversation,
        [
          { author: 'User', message: 'Test user prompt' },
          { author: opts[:default_conversation_name], message: 'Assistant Output #1' },
          { author: 'User', message: 'Test another user prompt' },
          { author: opts[:default_conversation_name], message: 'Assistant Output #2' },
          { author: 'User', message: 'What?' },
          { author: opts[:default_conversation_name], message: 'Assistant Output #3' }
        ]
      )
    end

    it 'persists the conversation through a JSON-serializable state' do
      agent.run(user_message: 'First message')
      agent.run(user_message: 'Second message')
      state = agent.export_state
      # Should be JSON-serializable
      expect { JSON.parse(state.to_json) }.not_to raise_error
      other_agent = new_agent(
        mocked_assistant_outputs: 'Other Assistant Output #1',
        name: 'Test Other Assistant'
      )
      other_agent.import_state(state)
      # Re-imported state should be the same
      expect(other_agent.export_state).to eq state
      expect_conversation(
        other_agent.conversation,
        [
          { author: 'User', message: 'First message' },
          { author: opts[:default_conversation_name], message: 'Assistant Output #1' },
          { author: 'User', message: 'Second message' },
          { author: opts[:default_conversation_name], message: 'Assistant Output #2' }
        ]
      )
      # State persistence should work across runs: it continues with correct state
      other_agent.run(user_message: 'Third message')
      expect_conversation(
        other_agent.conversation,
        [
          { author: 'User', message: 'First message' },
          { author: opts[:default_conversation_name], message: 'Assistant Output #1' },
          { author: 'User', message: 'Second message' },
          { author: opts[:default_conversation_name], message: 'Assistant Output #2' },
          { author: 'User', message: 'Third message' },
          { author: 'Agent Test Other Assistant', message: 'Other Assistant Output #1' }
        ]
      )
    end
  end
end
