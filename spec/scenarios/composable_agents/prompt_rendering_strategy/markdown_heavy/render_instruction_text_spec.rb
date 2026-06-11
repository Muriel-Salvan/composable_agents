describe ComposableAgents::PromptRenderingStrategy::MarkdownHeavy, '#render_instruction_text' do
  it 'returns the instruction unchanged' do
    expect(agent_for_markdown_heavy.render_instruction_text('This is a test instruction')).to eq('This is a test instruction')
  end

  it 'handles empty string correctly' do
    expect(agent_for_markdown_heavy.render_instruction_text('')).to eq('')
  end

  it 'handles multi-line text correctly' do
    expect(agent_for_markdown_heavy.render_instruction_text("Line 1\nLine 2\nLine 3")).to eq("Line 1\nLine 2\nLine 3")
  end
end
