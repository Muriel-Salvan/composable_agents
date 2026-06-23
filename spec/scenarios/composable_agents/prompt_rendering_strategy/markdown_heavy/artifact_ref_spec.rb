describe ComposableAgents::PromptRenderingStrategy::MarkdownHeavy, '#artifact_ref' do
  it 'converts a symbol artifact name to an uppercase string with ARTIFACT_ prefix' do
    expect(agent_for_markdown_heavy.artifact_ref(:plan)).to eq('ARTIFACT_PLAN')
  end

  it 'converts a snake_case name correctly' do
    expect(agent_for_markdown_heavy.artifact_ref(:monthly_report)).to eq('ARTIFACT_MONTHLY_REPORT')
  end
end
