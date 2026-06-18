require_relative '../shared_examples/prompt_driven_agent_examples'
require_relative '../shared_examples/prompt_driven_agent_with_contracts_examples'

describe ComposableAgents::AiAgents::Agent do
  # Mock an agent runner run for a given agent.
  # This will mock calls to Agents::AgentRunner and set spies in an agent.
  #
  # @param agent [ComposableAgents::Agent] The agent to be used to spy on AgentRunner
  # @param mocked_run_results [Array<Hash{Symbol => Object}>, Hash{Symbol => Object}] List of (or single)
  #   mocked results that will be returned by AgentRunner#run, for each call to AgentRunner#run.
  #   The following properties are used by our mock:
  #   - output_artifacts [Hash{Symbol => Object}] The output artifacts that should also be returned by this run.
  def mock_agent_runner_for(agent, mocked_run_results = [])
    mocked_run_results = [mocked_run_results] unless mocked_run_results.is_a?(Array)
    allow(Agents::AgentRunner).to receive(:new) do |agents|
      agent.spy_system_prompt = agents.first.instructions
      instance = instance_double(Agents::AgentRunner)
      allow(instance).to receive(:run) do |user_prompt, context:|
        agent.spy_user_prompts ||= []
        agent.spy_user_prompts << user_prompt
        agent.spy_contexts ||= []
        agent.spy_contexts << context
        mocked_run_result = mocked_run_results.shift
        mocked_output_artifacts = mocked_run_result&.delete(:output_artifacts)
        if mocked_output_artifacts
          # Use a mocked call to the corresponding tool
          tool_agent = agents
            .first
            .tools
            .find { |tool| tool.is_a?(ComposableAgents::AiAgents::Tools::CreateArtifactTool) }
            .instance_variable_get(:@agent)
          mocked_output_artifacts.each { |name, content| tool_agent.save_output_artifact(name, content) }
        end
        run_idx = (context[:run_idx] || 0) + 1
        double(
          **(
            mocked_run_result || {
              error: nil,
              context: { run_idx: },
              output: "Output of AgentRunner run ##{run_idx}"
            }
          )
        )
      end
      instance
    end
    # Add spies to the agent for the mock to work properly and make it inspectable.
    class << agent
      include ComposableAgentsTest::PromptDrivenAgentSpies

      # @return [Array<Hash>] List of AgentRunner contexts that have been used for each run.
      attr_accessor :spy_contexts
    end
  end

  # Convert the desired mocked outputs to the AgentRunner mocked outputs
  #
  # @param mocked_assistant_outputs [Array<Object>, Object] List of (or single) assistant outputs (see shared examples)
  # @return [Array<Hash{Symbol => Object}>] The corresponding AgentRunner mocked results
  def mocked_outputs_to_agent_runner_outputs(mocked_assistant_outputs)
    # Normalize the mocked outputs
    (mocked_assistant_outputs.is_a?(Array) ? mocked_assistant_outputs : [mocked_assistant_outputs]).map do |desc|
      desc = { text: desc } unless desc.is_a?(Hash)
      {
        error: nil,
        context: {},
        output: desc[:text],
        output_artifacts: desc[:output_artifacts]
      }
    end
  end

  it_behaves_like(
    'a prompt driven agent',
    new_agent: proc do |example, mocked_assistant_outputs: [], **kwargs|
      example.instance_eval do
        agent = described_class.new(**kwargs)
        mock_agent_runner_for(
          agent,
          mocked_outputs_to_agent_runner_outputs(mocked_assistant_outputs)
        )
        agent
      end
    end
  )

  it_behaves_like(
    'a prompt driven agent with artifacts contracts',
    new_agent: proc do |example, mocked_assistant_outputs: [], **kwargs|
      agent = Class.new(described_class) do
        prepend ComposableAgents::Mixins::ArtifactContract
      end.new(**kwargs)
      example.instance_eval do
        mock_agent_runner_for(
          agent,
          mocked_outputs_to_agent_runner_outputs(mocked_assistant_outputs)
        )
      end
      agent
    end
  )

  # Helper method to instantiate an Agent with test rendering strategy.
  #
  # @param params [Hash] Parameters to pass to the agent constructor.
  # @return [ComposableAgents::Agent] The agent
  def described_agent(**params)
    described_class.new(
      strategy: ComposableAgentsTest::TestRenderingStrategy,
      **params
    )
  end

  describe 'executing a prompt' do
    it 'raises an exception with error content when AgentRunner#run returns an error' do
      agent = described_agent
      mock_agent_runner_for(
        agent,
        {
          error: double(
            backtrace: ['backtrace line 1', 'backtrace line 2'],
            detailed_message: 'Test error message',
            response: double(response_body: 'Detailed error message')
          ),
          context: {},
          output: nil
        }
      )
      expect { agent.run }.to raise_error(
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

  describe 'the agent\'s context' do
    it 'continues with the same context when prompted several times' do
      agent = described_agent
      mock_agent_runner_for(agent)
      3.times { agent.run }
      expect(agent.spy_contexts).to eq [
        {},
        { run_idx: 1 },
        { run_idx: 2 }
      ]
    end

    it 'persists the context through a JSON-serializable state' do
      agent1 = described_agent(name: 'Test Agent 1')
      mock_agent_runner_for(agent1)
      agent1.run(user_instructions: 'First message')
      agent1.run(user_instructions: 'Second message')
      state = agent1.export_state
      # Check that context is JSON-serializable
      expect { JSON.parse(state.to_json) }.not_to raise_error
      # Import the context in another agent
      agent2 = described_agent(name: 'Test Agent 2')
      mock_agent_runner_for(agent2)
      agent2.import_state(state)
      expect(agent2.export_state).to eq state
      # Verify context is preserved and identical
      agent2.run(user_instructions: 'Third message')
      expect(agent2.spy_contexts).to eq [
        { run_idx: 2 }
      ]
    end
  end
end
