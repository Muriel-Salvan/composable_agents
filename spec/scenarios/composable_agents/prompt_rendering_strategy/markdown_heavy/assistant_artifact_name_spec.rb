describe ComposableAgents::PromptRenderingStrategy::MarkdownHeavy, '.assistant_artifact_name' do
  it 'converts a symbol artifact name to an uppercase string with ARTIFACT_ prefix' do
    expect(described_class.assistant_artifact_name(:plan)).to eq('ARTIFACT_PLAN')
  end

  it 'converts a snake_case name correctly' do
    expect(described_class.assistant_artifact_name(:monthly_report)).to eq('ARTIFACT_MONTHLY_REPORT')
  end
end
