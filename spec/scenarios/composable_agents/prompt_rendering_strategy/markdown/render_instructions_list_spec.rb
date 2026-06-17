describe ComposableAgents::PromptRenderingStrategy::Markdown, '#render_instructions_list' do
  it 'renders a list of plain instructions' do
    expect(
      agent_for_markdown.render_instructions_list(['Instruction 1', 'Instruction 2', 'Instruction 3'])
    ).to eq "Instruction 1\n\nInstruction 2\n\nInstruction 3"
  end

  it 'handles single instruction list' do
    expect(
      agent_for_markdown.render_instructions_list(['Single instruction'])
    ).to eq 'Single instruction'
  end

  it 'handles empty list' do
    expect(agent_for_markdown.render_instructions_list([])).to eq ''
  end

  it 'levels big headers in instructions properly' do
    expect(
      agent_for_markdown.render_instructions_list(
        [
          "# Header 1\n\n## 1. Header 1.1\n\n## 2. Header 1.2",
          '# Header 2'
        ]
      )
    ).to eq <<~EO_RENDERED.strip
      # Header 1

      ## 1. Header 1.1

      ## 2. Header 1.2

      # Header 2
    EO_RENDERED
  end

  it 'levels small headers in instructions properly' do
    expect(
      agent_for_markdown.render_instructions_list(
        [
          "### Header 1\n\n#### Header 1.1\n\n##### Header 1.1.1",
          '#### Header 2'
        ]
      )
    ).to eq <<~EO_RENDERED.strip
      # Header 1

      ## Header 1.1

      ### Header 1.1.1

      # Header 2
    EO_RENDERED
  end

  it 'strips each instruction of surrounding whitespace' do
    expect(
      agent_for_markdown.render_instructions_list(["  Instruction with spaces  \n", "\nInstruction 2\n  "])
    ).to eq "Instruction with spaces\n\nInstruction 2"
  end

  it 'handles instructions with mixed header levels' do
    expect(
      agent_for_markdown.render_instructions_list(
        [
          "# Top header\n\nSome content\n\n### Sub section",
          "#### Another section\n\nPlain text"
        ]
      )
    ).to eq <<~EO_RENDERED.strip
      # Top header

      Some content

      ### Sub section

      # Another section

      Plain text
    EO_RENDERED
  end
end
