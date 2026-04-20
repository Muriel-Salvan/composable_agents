describe ComposableAgents::AiAgents::Agent do
  # [Array<Hash<Symbol, Object>>] List of mocked output artifacts that will be set in the CreateArtifact tool,
  #    for each call to AgentRunner#run.
  attr_accessor :mocked_output_artifacts

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
      double(error: nil, context: { run_idx: }, output: "Output of AgentRunner run ##{run_idx}")
    end
    runner_instance
  end

  before do
    @mocked_output_artifacts = []
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
  # @param run_args [Hash] Arguments to pass to the #run method.
  # @param params [Hash] Parameters to pass to the agent constructor.
  # @return [Hash<Symbol, Object>] The output artifacts returned by the agent run
  def run_agent(run_args: {}, **params)
    described_agent(**params).run(**run_args)
  end

  # Expect system instructions received by the agent to be a given String
  #
  # @param expected_instructions [String] The expected instructions
  def expect_instructions_to_be(expected_instructions)
    expect(Agents::AgentRunner).to have_received(:new).with(
      satisfy { |agents| agents.first.instructions == expected_instructions }
    )
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
      run_agent(instructions: 'Test instruction', run_args: { user_message: 'Hello user' })
      expect(runner_double).to have_received(:run).with('USER_PROMPT: Hello user', anything)
    end

    it 'passes input artifacts to prompt rendering' do
      input_artifacts = { data: 'test data', config: { key: 'value' } }
      agent = described_agent(instructions: 'Test instruction')
      agent.run(input_artifacts:)
      expect(agent.render_calls).to include([:render_system_prompt, anything, input_artifacts])
      expect(agent.render_calls).to include([:render_user_prompt, '', input_artifacts])
    end
  end

  describe 'retry until all output artifacts have been provided' do
    let(:agent) do
      (
        Class.new(described_class) do
          prepend ComposableAgents::Mixins::ArtifactContract

          output_artifacts result: 'Final result', logs: 'Execution logs'
        end
      ).new(
        objective: 'Test objective',
        strategy: ComposableAgentsTest::TestRenderingStrategy,
        model: 'test-model',
        instructions: 'Test instructions'
      )
    end

    it 'does not retry when there are no expected output artifacts' do
      run_agent(instructions: 'Test')
      expect(runner_double).to have_received(:run).once
    end

    it 'does not retry when all expected artifacts are returned on first run' do
      mocked_output_artifacts << { result: 'ok', logs: 'logs' }
      expect(agent.run).to eq(result: 'ok', logs: 'logs')
      expect(runner_double).to have_received(:run).once
    end

    it 'retries once when some artifacts are missing on first run' do
      mocked_output_artifacts.push(
        { result: 'partial' },
        { result: 'partial', logs: 'complete' }
      )
      expect(agent.run).to eq(result: 'partial', logs: 'complete')
      expect(agent.render_calls).to include([:render_missing_output_user_prompt, { logs: 'Execution logs' }])
      expect(agent_runner_runs).to eq [
        { user_prompt: 'USER_PROMPT: ', context: {} },
        { user_prompt: 'MISSING_PROMPT: logs (Execution logs)', context: { run_idx: 1 } }
      ]
    end

    it 'retries multiple times until all artifacts are present' do
      mocked_output_artifacts.push(
        {},
        { result: 'first' },
        { result: 'second', logs: 'final' }
      )
      expect(agent.run).to eq(result: 'second', logs: 'final')
      expect(agent_runner_runs).to eq [
        { user_prompt: 'USER_PROMPT: ', context: {} },
        { user_prompt: 'MISSING_PROMPT: result (Final result), logs (Execution logs)', context: { run_idx: 1 } },
        { user_prompt: 'MISSING_PROMPT: logs (Execution logs)', context: { run_idx: 2 } }
      ]
    end
  end
end
