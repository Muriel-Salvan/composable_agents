describe ComposableAgents::PromptRenderingStrategy::Markdown, '#render_user_prompt' do
  it 'returns the rendered instructions unchanged' do
    expect(agent_for_markdown.render_user_prompt('Hello, I need assistance')).to eq('Hello, I need assistance')
  end

  it 'handles nil rendered instructions correctly' do
    expect(agent_for_markdown.render_user_prompt(nil)).to eq('')
  end

  it 'handles empty rendered instructions correctly' do
    expect(agent_for_markdown.render_user_prompt('')).to eq('')
  end

  it 'does not use input artifacts' do
    expect(agent_for_markdown.render_user_prompt('Hello, I need assistance', input_artifacts: { key: 'value' })).to eq('Hello, I need assistance')
  end
end
