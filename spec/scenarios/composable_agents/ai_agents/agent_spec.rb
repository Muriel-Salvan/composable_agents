describe ComposableAgents::AiAgents::Agent do
  # [Array<Hash<Symbol, Object>>] List of mocked output artifacts that will be set in the CreateArtifact tool,
  #    for each call to AgentRunner#run.
  attr_accessor :mocked_output_artifacts

  # [Array<Hash<Symbol, Object>>] List of mocked results that will be returned by AgentRunner#run,
  #    for each call to AgentRunner#run.
  attr_accessor :mocked_run_results

  # [Array<Agents::Agent>] List of agents that were given to AgentRunner.new
  attr_reader :agent_runner_agents

  # [Array<Hash<Symbol, Object>>] List of AgentRunner#run call arguments that have been performed
  attr_reader :agent_runner_runs

  let(:runner_double) do
    runner_instance = instance_double(Agents::AgentRunner)
    allow(runner_instance).to receive(:run) do |user_prompt, context:|
      agent_runner_runs << {
        user_prompt:,
        context:
      }
      run_idx = (context[:run_idx] || 0) + 1
      artifacts = mocked_output_artifacts.shift
      unless artifacts.nil?
        agent_runner_agents
          .first
          .tools
          .find { |tool| tool.is_a?(ComposableAgents::AiAgents::Tools::CreateArtifactTool) }
          .instance_variable_get(:@artifacts)
          .merge!(artifacts)
      end
      double(
        **(
          mocked_run_results.shift || {
            error: nil,
            context: { run_idx: },
            output: "Output of AgentRunner run ##{run_idx}"
          }
        )
      )
    end
    runner_instance
  end

  before do
    @mocked_output_artifacts = []
    @mocked_run_results = []
    @agent_runner_runs = []
    allow(Agents::AgentRunner).to receive(:new) do |agents|
      @agent_runner_agents = agents
      runner_double
    end
  end

  # Helper method to instantiate an Agent with default test parameters
  # @param params [Hash] Parameters to pass to the agent constructor.
  # @return [ComposableAgents::Agent] The agent
  def described_agent(**params)
    described_class.new(
      objective: 'Test objective',
      strategy: ComposableAgentsTest::TestRenderingStrategy,
      model: 'test-model',
      instructions: 'Test instruction',
      **params
    )
  end

  # Helper method to run an Agent with default test parameters
  # @param input_artifacts [Hash] Input artifacts to pass to the #run method.
  # @param params [Hash] Parameters to pass to the agent constructor.
  # @return [Hash<Symbol, Object>] The output artifacts returned by the agent run
  def run_agent(input_artifacts: {}, **params)
    described_agent(**params).run(**input_artifacts)
  end

  # Expect system instructions received by the agent to be a given String
  #
  # @param expected_instructions [String] The expected instructions
  def expect_instructions_to_be(expected_instructions)
    expect(Agents::AgentRunner).to have_received(:new).with(
      satisfy { |agents| agents.first.instructions == expected_instructions }
    )
  end

  describe 'attributes' do
    describe '#model' do
      it 'returns the model that was set in initialization' do
        expect(described_agent(model: 'gpt-4o-test').model).to eq 'gpt-4o-test'
      end

      it 'uses default model when not specified explicitly' do
        allow(Agents.configuration).to receive(:default_model).and_return('default-test-model')
        expect(described_class.new.model).to eq 'default-test-model'
      end
    end
  end

  describe 'instruction rendering' do
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
      it "handles #{description}" do
        run_agent(instructions: test_data[:instructions])
        expect_instructions_to_be "SYSTEM_PROMPT[#{test_data[:system_prompt]}]"
      end
    end
  end

  describe 'prompt passing to AgentRunner' do
    it 'passes correctly rendered system prompt to AgentRunner' do
      run_agent(instructions: 'Test instruction')
      expect_instructions_to_be 'SYSTEM_PROMPT[RENDERED_TEXT: Test instruction]'
    end

    it 'passes correctly rendered user prompt to AgentRunner#run' do
      run_agent(instructions: 'Test instruction', input_artifacts: { user_message: 'Hello user' })
      expect(runner_double).to have_received(:run).with('USER_PROMPT: Hello user', anything)
    end

    it 'passes input artifacts to prompt rendering' do
      input_artifacts = { data: 'test data', config: { key: 'value' } }
      agent = described_agent(instructions: 'Test instruction')
      agent.run(**input_artifacts)
      expect(agent.render_calls).to include([:render_system_prompt, anything, input_artifacts])
      expect(agent.render_calls).to include([:render_user_prompt, '', input_artifacts])
    end

    it 'raises an exception with error content when AgentRunner#run returns an error' do
      mocked_run_results << {
        error: double(
          backtrace: ['backtrace line 1', 'backtrace line 2'],
          detailed_message: 'Test error message',
          response: double(response_body: 'Detailed error message')
        ),
        context: {},
        output: nil
      }
      expect { run_agent(instructions: 'Test instruction') }.to raise_error(
        RuntimeError,
        <<~EO_ERROR.strip
          Error: Test error message
          backtrace line 1
          backtrace line 2
          Detailed error message
        EO_ERROR
      )
    end
  end

  describe 'retry until all output artifacts have been provided' do
    let(:agent) do
      (
        Class.new(described_class) do
          prepend ComposableAgents::Mixins::ArtifactContract
        end
      ).new(
        objective: 'Test objective',
        strategy: ComposableAgentsTest::TestRenderingStrategy,
        model: 'test-model',
        instructions: 'Test instructions',
        input_artifacts: {},
        output_artifacts: { result: 'Final result', logs: 'Execution logs' }
      )
    end

    it 'does not retry when there are no expected output artifacts' do
      run_agent(instructions: 'Test')
      expect(runner_double).to have_received(:run).once
    end

    it 'does not retry when all expected artifacts are returned on first run' do
      mocked_output_artifacts << { result: 'ok', logs: 'logs' }
      expect(agent.run).to include(result: 'ok', logs: 'logs')
      expect(runner_double).to have_received(:run).once
    end

    it 'retries once when some artifacts are missing on first run' do
      mocked_output_artifacts.push(
        { result: 'partial' },
        { result: 'partial', logs: 'complete' }
      )
      expect(agent.run).to include(result: 'partial', logs: 'complete')
      expect(agent.render_calls).to include([:missing_output_user_prompt, { logs: 'Execution logs' }])
      expect(agent_runner_runs).to eq [
        { user_prompt: 'USER_PROMPT: ', context: {} },
        { user_prompt: 'USER_PROMPT: MISSING_PROMPT: logs (Execution logs)', context: { run_idx: 1 } }
      ]
    end

    it 'retries multiple times until all artifacts are present' do
      mocked_output_artifacts.push(
        {},
        { result: 'first' },
        { result: 'second', logs: 'final' }
      )
      expect(agent.run).to include(result: 'second', logs: 'final')
      expect(agent_runner_runs).to eq [
        { user_prompt: 'USER_PROMPT: ', context: {} },
        { user_prompt: 'USER_PROMPT: MISSING_PROMPT: result (Final result), logs (Execution logs)', context: { run_idx: 1 } },
        { user_prompt: 'USER_PROMPT: MISSING_PROMPT: logs (Execution logs)', context: { run_idx: 2 } }
      ]
    end
  end

  describe 'state' do
    it 'continues with the same context when prompted several times' do
      agent = described_agent
      3.times { agent.run }
      expect(agent_runner_runs).to eq [
        { user_prompt: 'USER_PROMPT: ', context: {} },
        { user_prompt: 'USER_PROMPT: ', context: { run_idx: 1 } },
        { user_prompt: 'USER_PROMPT: ', context: { run_idx: 2 } }
      ]
    end

    it 'exports state that is JSON-serializable' do
      agent = described_agent
      agent.run
      state = agent.export_state
      expect(JSON.parse(state.to_json)).to eq state
    end

    it 'imports state correctly restoring context' do
      agent1 = described_agent
      agent1.run
      state = agent1.export_state

      agent2 = described_agent
      agent2.import_state(state)
      expect(agent2.export_state).to eq state
    end
  end

  describe 'conversation' do
    # Expect conversation to follow a given sequence.
    # This validates the authors and messages.
    # It also makes sure that timestamps are ordered properly and with a proper format.
    #
    # @param conversation [Array<Hash<Symbol, String>>] The recorded conversation
    # @param expected_conversation [Array<Hash<Symbol, String>>] The expected conversation
    def expect_conversation(conversation, expected_conversation)
      expect(conversation.map { |message| message.except(:at) }).to eq expected_conversation
      timestamps = conversation.map do |message|
        expect(message[:at]).to match(/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/)
        message[:at]
      end
      expect(timestamps.sort).to eq timestamps
    end

    context 'without output artifacts contracts' do
      let(:agent) do
        described_class.new(
          name: 'Test Agent Name',
          strategy: ComposableAgentsTest::TestRenderingStrategy
        )
      end

      it 'records the prompt' do
        agent.run(user_message: 'Test user prompt')
        expect_conversation(
          agent.conversation,
          [
            { author: 'User', message: 'Test user prompt' },
            { author: 'Agent Test Agent Name', message: 'Output of AgentRunner run #1' }
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
            { author: 'Agent Test Agent Name', message: 'Output of AgentRunner run #1' },
            { author: 'User', message: 'Test another user prompt' },
            { author: 'Agent Test Agent Name', message: 'Output of AgentRunner run #2' },
            { author: 'User', message: 'What?' },
            { author: 'Agent Test Agent Name', message: 'Output of AgentRunner run #3' }
          ]
        )
      end
    end

    context 'with output artifacts contracts' do
      let(:agent) do
        Class.new(described_class) do
          prepend ComposableAgents::Mixins::ArtifactContract
        end.new(
          strategy: ComposableAgentsTest::TestRenderingStrategy,
          input_artifacts: {},
          output_artifacts: { result: 'Final result', logs: 'Execution logs' }
        )
      end

      it 'records retry prompts when there are output artifact contracts and 1 retry' do
        mocked_output_artifacts.push(
          {},
          { result: 'complete', logs: 'success' }
        )
        agent.run
        expect_conversation(
          agent.conversation,
          [
            { author: 'User', message: '' },
            { author: 'Agent Executor', message: 'Output of AgentRunner run #1' },
            { author: 'User', message: 'MISSING_PROMPT: result (Final result), logs (Execution logs)' },
            { author: 'Agent Executor', message: 'Output of AgentRunner run #2' }
          ]
        )
      end

      it 'records all retries when there are multiple missing artifacts, several retries and runs' do
        mocked_output_artifacts.push(
          {},
          { result: 'first' },
          { result: 'second', logs: 'final' },
          { result: 'second', logs: 'final' }
        )
        agent.run
        agent.run(user_message: 'Again')
        expect_conversation(
          agent.conversation,
          [
            { author: 'User', message: '' },
            { author: 'Agent Executor', message: 'Output of AgentRunner run #1' },
            { author: 'User', message: 'MISSING_PROMPT: result (Final result), logs (Execution logs)' },
            { author: 'Agent Executor', message: 'Output of AgentRunner run #2' },
            { author: 'User', message: 'MISSING_PROMPT: logs (Execution logs)' },
            { author: 'Agent Executor', message: 'Output of AgentRunner run #3' },
            { author: 'User', message: 'Again' },
            { author: 'Agent Executor', message: 'Output of AgentRunner run #4' }
          ]
        )
      end
    end
  end
end
