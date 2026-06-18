require 'json'

shared_examples 'a prompt driven agent' do |opts|
  # Possible options for opts:
  # - new_agent [#call(example, **kwargs) -> Agent] Factory proc that initializes a new agent, decorated for testing purposes.
  #   The returned instance should provide the method `spy -> Hash{Symbol, Object}` so that the test scenarios can inspect the agent.
  #   The returned spy should have the following properties:
  #     - role [String, nil] The agent's role
  #     - objective [String, nil] The agent's objective
  #     - system_instructions [Object, nil] The agent's normalized system instructions
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
        system_instructions: 'Read and run test files',
        constraints: 'Don\'t write files'
      ).spy
      expect(agent_spy[:role]).to eq 'Test Executor'
      expect(agent_spy[:objective]).to eq 'Execute tests'
      expect(agent_spy[:system_instructions].to_a).to eq [[:text, 'Read and run test files']]
      expect(agent_spy[:constraints]).to eq 'Don\'t write files'
    end
  end

  describe 'the system prompt' do
    describe 'the rendering of instructions' do
      {
        'nil system_instructions': {
          system_instructions: nil,
          system_prompt: ''
        },
        'single String': {
          system_instructions: 'Single instruction',
          system_prompt: 'RENDERED_TEXT: Single instruction'
        },
        'single Hash with :text key': {
          system_instructions: { text: 'Hash text instruction' },
          system_prompt: 'RENDERED_TEXT: Hash text instruction'
        },
        'single Hash with :ordered_list key': {
          system_instructions: { ordered_list: ['Step 1', 'Step 2', 'Step 3'] },
          system_prompt: 'RENDERED_LIST: Step 1, Step 2, Step 3'
        },
        'Hash with multiple types': {
          system_instructions: {
            text: 'Do this task:',
            ordered_list: ['First step', 'Second step']
          },
          system_prompt: 'RENDERED_TEXT: Do this task: | RENDERED_LIST: First step, Second step'
        },
        'Array of mixed types': {
          system_instructions: [
            'First instruction',
            { text: 'Second instruction' },
            { ordered_list: ['Step A', 'Step B'] }
          ],
          system_prompt: 'RENDERED_TEXT: First instruction | RENDERED_TEXT: Second instruction | RENDERED_LIST: Step A, Step B'
        }
      }.each do |description, test_data|
        context "when handling #{description}" do
          it 'sets the system prompt without artifacts' do
            agent = new_agent(system_instructions: test_data[:system_instructions])
            agent.run
            expect(agent.spy[:system_prompt]).to eq "SYSTEM_PROMPT[#{test_data[:system_prompt]}]"
          end

          it 'does not use the user instructions in the system prompt' do
            agent = new_agent(system_instructions: test_data[:system_instructions])
            agent.run(user_instructions: 'Do this')
            expect(agent.spy[:system_prompt]).to eq "SYSTEM_PROMPT[#{test_data[:system_prompt]}]"
          end

          it 'uses the input artifacts in the system prompt' do
            agent = new_agent(
              **{
                system_instructions: test_data[:system_instructions],
                input_artifacts_contracts: opts[:contracts] ? { test_artifact: 'Description' } : nil
              }.compact
            )
            agent.run(user_instructions: 'Do this', test_artifact: 'Content')
            expect(agent.spy[:system_prompt]).to eq "SYSTEM_PROMPT[#{test_data[:system_prompt]} with test_artifact (Content)]"
          end
        end
      end
    end
  end

  describe 'the user prompt' do
    describe 'the rendering of user instructions' do
      {
        'nil user_instructions': {
          user_instructions: nil,
          user_prompt: ''
        },
        'single String': {
          user_instructions: 'Single instruction',
          user_prompt: 'RENDERED_TEXT: Single instruction'
        },
        'single Hash with :text key': {
          user_instructions: { text: 'Hash text instruction' },
          user_prompt: 'RENDERED_TEXT: Hash text instruction'
        },
        'single Hash with :ordered_list key': {
          user_instructions: { ordered_list: ['Step 1', 'Step 2', 'Step 3'] },
          user_prompt: 'RENDERED_LIST: Step 1, Step 2, Step 3'
        },
        'Hash with multiple types': {
          user_instructions: {
            text: 'Do this task:',
            ordered_list: ['First step', 'Second step']
          },
          user_prompt: 'RENDERED_TEXT: Do this task: | RENDERED_LIST: First step, Second step'
        },
        'Array of mixed types': {
          user_instructions: [
            'First instruction',
            { text: 'Second instruction' },
            { ordered_list: ['Step A', 'Step B'] }
          ],
          user_prompt: 'RENDERED_TEXT: First instruction | RENDERED_TEXT: Second instruction | RENDERED_LIST: Step A, Step B'
        }
      }.each do |description, test_data|
        context "when handling #{description}" do
          it 'sends the instructions in the user prompt' do
            agent = new_agent(mocked_assistant_outputs: 'Assistant Output')
            agent.run(user_instructions: test_data[:user_instructions])
            expect(agent.spy[:user_prompts]).to eq ["USER_PROMPT[#{test_data[:user_prompt]}]"]
          end

          it 'does not use the user instructions in the system prompt' do
            agent = new_agent(mocked_assistant_outputs: 'Assistant Output', system_instructions: 'System instructions')
            agent.run(user_instructions: test_data[:user_instructions])
            expect(agent.spy[:system_prompt]).to eq 'SYSTEM_PROMPT[RENDERED_TEXT: System instructions]'
          end

          it 'uses the input artifacts in the user prompt' do
            agent = new_agent(
              mocked_assistant_outputs: 'Assistant Output',
              **{
                input_artifacts_contracts: opts[:contracts] ? { test_artifact: 'Description' } : nil
              }.compact
            )
            agent.run(user_instructions: test_data[:user_instructions], test_artifact: 'Content')
            expect(agent.spy[:user_prompts]).to eq ["USER_PROMPT[#{test_data[:user_prompt]} with test_artifact (Content)]"]
          end
        end
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
      agent.run(user_instructions: 'Test user prompt')
      expect_conversation(
        agent.conversation,
        [
          { author: 'User', message: 'RENDERED_TEXT: Test user prompt' },
          { author: opts[:default_conversation_name], message: 'Assistant Output #1' }
        ]
      )
    end

    it 'records the prompt using a specific agent name' do
      named_agent = new_agent(
        mocked_assistant_outputs: ['Assistant Output #1'],
        name: 'Test Assistant'
      )
      named_agent.run(user_instructions: 'Test user prompt')
      expect_conversation(
        named_agent.conversation,
        [
          { author: 'User', message: 'RENDERED_TEXT: Test user prompt' },
          { author: 'Agent Test Assistant', message: 'Assistant Output #1' }
        ]
      )
    end

    it 'records the prompts of several runs' do
      agent.run(user_instructions: 'Test user prompt')
      agent.run(user_instructions: 'Test another user prompt')
      agent.run(user_instructions: 'What?')
      expect_conversation(
        agent.conversation,
        [
          { author: 'User', message: 'RENDERED_TEXT: Test user prompt' },
          { author: opts[:default_conversation_name], message: 'Assistant Output #1' },
          { author: 'User', message: 'RENDERED_TEXT: Test another user prompt' },
          { author: opts[:default_conversation_name], message: 'Assistant Output #2' },
          { author: 'User', message: 'RENDERED_TEXT: What?' },
          { author: opts[:default_conversation_name], message: 'Assistant Output #3' }
        ]
      )
    end

    it 'persists the conversation through a JSON-serializable state' do
      agent.run(user_instructions: 'First message')
      agent.run(user_instructions: 'Second message')
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
          { author: 'User', message: 'RENDERED_TEXT: First message' },
          { author: opts[:default_conversation_name], message: 'Assistant Output #1' },
          { author: 'User', message: 'RENDERED_TEXT: Second message' },
          { author: opts[:default_conversation_name], message: 'Assistant Output #2' }
        ]
      )
      # State persistence should work across runs: it continues with correct state
      other_agent.run(user_instructions: 'Third message')
      expect_conversation(
        other_agent.conversation,
        [
          { author: 'User', message: 'RENDERED_TEXT: First message' },
          { author: opts[:default_conversation_name], message: 'Assistant Output #1' },
          { author: 'User', message: 'RENDERED_TEXT: Second message' },
          { author: opts[:default_conversation_name], message: 'Assistant Output #2' },
          { author: 'User', message: 'RENDERED_TEXT: Third message' },
          { author: 'Agent Test Other Assistant', message: 'Other Assistant Output #1' }
        ]
      )
    end
  end
end
