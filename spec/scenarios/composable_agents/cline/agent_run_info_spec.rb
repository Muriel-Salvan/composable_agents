describe ComposableAgents::Cline::Agent do
  describe 'published run information' do
    # Model info used in mocked messages having usage metrics.
    # Note: keys in mocked messages use the camelCase JSON format of Cline session messages.
    let(:model_info) do
      { id: 'test-model', provider: 'test-provider', family: 'test' }
    end

    it 'publishes the cumulative usage (cost and tokens) of API requests realtime in the run info' do
      agent = cline_agent
      mock_cline_for(
        agent,
        {
          messages: [
            {
              ts: 100,
              modelInfo: model_info,
              role: 'assistant',
              content: [{ type: 'text', text: 'Response 1' }],
              metrics: { cost: 0.01, inputTokens: 100, outputTokens: 50, cacheReadTokens: 10, cacheWriteTokens: 5 }
            },
            {
              ts: 110,
              modelInfo: model_info,
              role: 'assistant',
              content: [{ type: 'text', text: 'Response 2' }],
              metrics: { cost: 0.02, inputTokens: 200, outputTokens: 80, cacheReadTokens: 20, cacheWriteTokens: 0 }
            }
          ]
        }
      )
      agent.run
      expect(agent.runs_info.size).to eq 1
      usage = agent.runs_info.last.usage
      expect(usage[:cost]).to be_within(1e-9).of(0.03)
      expect(usage[:input_tokens]).to eq 300
      expect(usage[:output_tokens]).to eq 130
      expect(usage[:cache_read_tokens]).to eq 30
      expect(usage[:cache_write_tokens]).to eq 5
      # Context tokens are taken from the last API request, not summed
      expect(usage[:context_tokens]).to eq 300
      expect(usage[:context_tokens_limit]).to be_nil
    end

    it 'does not publish usage when messages contain no metrics' do
      agent = cline_agent
      mock_cline_for(agent, { stdout: 'Response' })
      agent.run
      expect(agent.runs_info.last.respond_to?(:usage)).to be false
    end

    it 'resets the usage between runs' do
      agent = cline_agent
      metrics = { cost: 0.01, inputTokens: 100, outputTokens: 50, cacheReadTokens: 10, cacheWriteTokens: 5 }
      mocked_run_result = {
        messages: [
          {
            ts: 100,
            modelInfo: model_info,
            role: 'assistant',
            content: [{ type: 'text', text: 'Response' }],
            metrics:
          }
        ]
      }
      mock_cline_for(agent, [mocked_run_result, mocked_run_result])
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
