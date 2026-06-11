describe ComposableAgents::PromptRenderingStrategy::Markdown, '#render_instruction_text' do
  it 'returns the instruction' do
    expect(agent_for_markdown.render_instruction_text('This is a test instruction')).to eq('This is a test instruction')
  end

  it 'handles empty string correctly' do
    expect(agent_for_markdown.render_instruction_text('')).to eq('')
  end

  it 'handles multi-line text correctly' do
    expect(agent_for_markdown.render_instruction_text("Line 1\nLine 2\nLine 3")).to eq("Line 1\nLine 2\nLine 3")
  end
end
