describe ComposableAgents::PromptRenderingStrategy::Markdown, '#missing_output_user_instructions' do
  it 'prompts for missing artifacts as bullet points' do
    expect(
      agent_for_markdown.missing_output_user_instructions(
        report: { description: 'Final report document' },
        summary: { description: 'Executive summary' },
        logs: { description: 'Execution logs' }
      )
    ).to eq <<~EO_PROMPT
      Some artifacts are missing:
      - You must create an artifact named `report`: Final report document
      - You must create an artifact named `summary`: Executive summary
      - You must create an artifact named `logs`: Execution logs
    EO_PROMPT
  end

  it 'handles single missing artifact correctly' do
    expect(agent_for_markdown.missing_output_user_instructions(result: { description: 'Calculation result' })).to eq <<~EO_PROMPT
      Some artifacts are missing:
      - You must create an artifact named `result`: Calculation result
    EO_PROMPT
  end

  it 'does not report errors for missing artifacts' do
    expect(
      agent_for_markdown.missing_output_user_instructions(
        report: { description: 'Final report document', error: 'Missing file' },
        summary: { description: 'Executive summary' },
        logs: { description: 'Execution logs', error: 'No log' }
      )
    ).to eq <<~EO_PROMPT
      Some artifacts are missing:
      - You must create an artifact named `report`: Final report document
      - You must create an artifact named `summary`: Executive summary
      - You must create an artifact named `logs`: Execution logs
    EO_PROMPT
  end
end
