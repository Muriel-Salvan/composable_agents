describe ComposableAgents::AiAgents::Agent do
  describe 'published run information' do
    # Mock an agent runner run for a given agent, with LLM calls having usage metrics.
    # This will mock calls to Agents::AgentRunner, capture its on_llm_call_complete callback and
    #   invoke it with mocked RubyLLM messages during the mocked runs, mimicking the AgentRunner behaviour.
    #
    # @param agent [ComposableAgents::Agent] The agent to be mocked
    # @param mocked_runs_llm_calls [Array<Array<Hash{Symbol => Object}, nil>>] List of mocked runs' LLM calls:
    #   one entry per mocked AgentRunner#run, each containing the list of the LLM calls of this run.
    #   A nil entry in an LLM calls list mocks an LLM call without usage metrics.
    #   Each hash can have the following properties:
    #   - cost [Float] Monetary cost of the LLM call (as computed by RubyLLM from the model's pricing)
    #   - input_tokens [Integer] Number of input tokens of the LLM call
    #   - output_tokens [Integer] Number of output tokens of the LLM call
    #   - cache_read_tokens [Integer] Number of tokens read from cache by the LLM call
    #   - cache_write_tokens [Integer] Number of tokens written to cache by the LLM call
    #   - context_window [Integer, nil] Context window limit of the model used by the LLM call.
    #     If nil, the model is considered unknown by RubyLLM.
    def mock_agent_runner_with_llm_calls_for(_agent, mocked_runs_llm_calls)
      mocked_runs_llm_calls = [[nil]] if mocked_runs_llm_calls.nil?
      mocked_runs_llm_calls = [mocked_runs_llm_calls] unless mocked_runs_llm_calls.first.is_a?(Array)
      llm_call_callbacks = []
      allow(Agents::AgentRunner).to receive(:new) do |_agents|
        instance = instance_double(Agents::AgentRunner)
        allow(instance).to receive(:on_llm_call_complete) do |&callback|
          llm_call_callbacks << callback
          instance
        end
        allow(instance).to receive(:run) do |_user_prompt, context:|
          run_idx = (context[:run_idx] || 0) + 1
          mocked_runs_llm_calls[run_idx - 1]&.each do |metrics|
            llm_call_callbacks.each { |callback| callback.call('test-agent', 'test-model', mocked_llm_message(metrics)) }
          end
          double(error: nil, context: { run_idx: }, output: "Output of AgentRunner run ##{run_idx}")
        end
        instance
      end
    end

    # Helper method to instantiate an AiAgents Agent with test rendering strategy.
    #
    # @param params [Hash] Parameters to pass to the agent constructor.
    # @return [ComposableAgents::AiAgents::Agent] The agent
    def ai_agent(**params)
      described_class.new(
        composable_agents_dir: '.composable_agents_test',
        strategy: ComposableAgentsTest::TestRenderingStrategy,
        model: 'test-model',
        **params
      )
    end

    # Build a mocked RubyLLM message, as emitted by AgentRunner's on_llm_call_complete callback.
    #
    # @param metrics [Hash{Symbol => Object}, nil] Usage metrics (see mock_agent_runner_with_llm_calls_for)
    # @return [RubyLLM::Message] The mocked message
    def mocked_llm_message(metrics)
      return instance_double(RubyLLM::Message, tokens: nil) if metrics.nil?

      instance_double(
        RubyLLM::Message,
        tokens: instance_double(
          RubyLLM::Tokens,
          input: metrics[:input_tokens],
          output: metrics[:output_tokens],
          cache_read: metrics[:cache_read_tokens],
          cache_write: metrics[:cache_write_tokens],
          thinking: 0
        ),
        cost: instance_double(
          RubyLLM::Cost,
          input: metrics[:cost] || 0.0,
          output: 0.0,
          cache_read: 0.0,
          cache_write: 0.0,
          thinking: nil
        ),
        # RubyLLM::Message#model_info returns nil when the model is unknown in RubyLLM's registry
        model_info: metrics[:context_window] ? instance_double(RubyLLM::Model, context_window: metrics[:context_window]) : nil
      )
    end

    it 'publishes the cumulative usage (cost and tokens) of LLM calls realtime in the run info' do
      agent = ai_agent
      mock_agent_runner_with_llm_calls_for(
        agent,
        [
          [
            {
              cost: 0.01,
              input_tokens: 100,
              output_tokens: 50,
              cache_read_tokens: 10,
              cache_write_tokens: 5,
              context_window: 200_000
            },
            {
              cost: 0.02,
              input_tokens: 200,
              output_tokens: 80,
              cache_read_tokens: 20,
              cache_write_tokens: 0,
              context_window: 200_000
            }
          ]
        ]
      )
      agent.run
      expect(agent.runs_info.size).to eq 1
      usage = agent.runs_info.last.usage
      expect(usage[:cost]).to be_within(1e-9).of(0.03)
      expect(usage[:input_tokens]).to eq 300
      expect(usage[:output_tokens]).to eq 130
      expect(usage[:cache_read_tokens]).to eq 30
      expect(usage[:cache_write_tokens]).to eq 5
      # Context tokens are taken from the last LLM call, not summed
      expect(usage[:context_tokens]).to eq 300
      expect(usage[:context_tokens_limit]).to eq 200_000
    end

    it 'does not publish usage when LLM calls have no usage metrics' do
      agent = ai_agent
      mock_agent_runner_with_llm_calls_for(agent, [[nil]])
      agent.run
      expect(agent.runs_info.last.respond_to?(:usage)).to be false
    end

    it 'resets the usage between runs' do
      agent = ai_agent
      metrics = { cost: 0.01, input_tokens: 100, output_tokens: 50, cache_read_tokens: 10, cache_write_tokens: 5 }
      mock_agent_runner_with_llm_calls_for(agent, [[metrics], [metrics]])
      agent.run
      agent.run
      expect(agent.runs_info.size).to eq 2
      expect(agent.runs_info.last.usage[:cost]).to eq 0.01
      expect(agent.runs_info.last.usage[:input_tokens]).to eq 100
      expect(agent.runs_info.last.usage[:output_tokens]).to eq 50
      expect(agent.runs_info.last.usage[:cache_read_tokens]).to eq 10
      expect(agent.runs_info.last.usage[:cache_write_tokens]).to eq 5
      expect(agent.runs_info.last.usage[:context_tokens]).to eq 165
      expect(agent.runs_info.last.usage[:context_tokens_limit]).to be_nil
    end
  end
end
