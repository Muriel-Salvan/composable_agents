describe ComposableAgents::PromptRenderingStrategy::Markdown, '#render_instruction_ordered_list' do
  it 'renders an ordered list with correct numbering' do
    expect(
      agent_for_markdown.render_instruction_ordered_list(['First step', 'Second step', 'Third step'])
    ).to eq <<~EO_RENDERED_INSTRUCTION.strip
      # 1. First step

      # 2. Second step

      # 3. Third step

    EO_RENDERED_INSTRUCTION
  end

  it 'handles single item list correctly' do
    expect(agent_for_markdown.render_instruction_ordered_list(['Only one step'])).to eq('# 1. Only one step')
  end

  it 'handles empty list correctly' do
    expect(agent_for_markdown.render_instruction_ordered_list([])).to eq('')
  end
end
