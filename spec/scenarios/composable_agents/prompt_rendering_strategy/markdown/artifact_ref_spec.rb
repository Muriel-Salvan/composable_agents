describe ComposableAgents::PromptRenderingStrategy::Markdown, '#artifact_ref' do
  it 'returns the symbol name as a string without any prefix' do
    expect(agent_for_markdown.artifact_ref(:plan)).to eq('plan')
  end

  it 'converts a snake_case symbol to a string' do
    expect(agent_for_markdown.artifact_ref(:monthly_report)).to eq('monthly_report')
  end
end
