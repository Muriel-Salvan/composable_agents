describe ComposableAgents::PromptRenderingStrategy::MarkdownHeavy, '#render_user_prompt' do
  it 'returns only the user instructions section when input artifacts are empty' do
    expect(agent_for_markdown_heavy.render_user_prompt('Hello, I need assistance', input_artifacts: {})).to eq <<~EO_PROMPT.strip
      # User instructions

      Hello, I need assistance
    EO_PROMPT
  end

  it 'handles nil rendered instructions with no artifacts' do
    expect(agent_for_markdown_heavy.render_user_prompt(nil, input_artifacts: {})).to eq('')
  end

  it 'handles empty rendered instructions with no artifacts' do
    expect(agent_for_markdown_heavy.render_user_prompt('', input_artifacts: {})).to eq('')
  end

  it 'includes input artifacts section when input artifacts are provided' do
    expect(
      agent_for_markdown_heavy.render_user_prompt(
        'Process these documents',
        input_artifacts: {
          plan: 'Build a house',
          budget: { amount: 50_000, currency: 'EUR' }
        }
      )
    ).to eq <<~EO_PROMPT.strip
      # Input artifacts

      ## `ARTIFACT_PLAN`

      ```json input_artifact=ARTIFACT_PLAN
      "Build a house"
      ```

      ## `ARTIFACT_BUDGET`

      ```json input_artifact=ARTIFACT_BUDGET
      {"amount":50000,"currency":"EUR"}
      ```

      # User instructions

      Process these documents
    EO_PROMPT
  end

  it 'handles input artifacts with nil rendered instructions' do
    expect(
      agent_for_markdown_heavy.render_user_prompt(
        nil,
        input_artifacts: {
          plan: 'Just the plan'
        }
      )
    ).to eq <<~EO_PROMPT.strip
      # Input artifacts

      ## `ARTIFACT_PLAN`

      ```json input_artifact=ARTIFACT_PLAN
      "Just the plan"
      ```
    EO_PROMPT
  end

  it 'handles input artifacts with empty rendered instructions' do
    expect(
      agent_for_markdown_heavy.render_user_prompt(
        '',
        input_artifacts: {
          plan: 'Just the plan'
        }
      )
    ).to eq <<~EO_PROMPT.strip
      # Input artifacts

      ## `ARTIFACT_PLAN`

      ```json input_artifact=ARTIFACT_PLAN
      "Just the plan"
      ```
    EO_PROMPT
  end

  it 'levels big headers in rendered instructions properly' do
    expect(
      agent_for_markdown_heavy.render_user_prompt(
        <<~EO_INSTRUCTIONS,
          # Header 1

          ## 1. Header 1.1

          ## 2. Header 1.2
        EO_INSTRUCTIONS
        input_artifacts: {}
      )
    ).to eq <<~EO_PROMPT.strip
      # User instructions

      ## Header 1

      ### 1. Header 1.1

      ### 2. Header 1.2
    EO_PROMPT
  end

  it 'levels small headers in rendered instructions properly' do
    expect(
      agent_for_markdown_heavy.render_user_prompt(
        <<~EO_INSTRUCTIONS,
          ### Header 1

          #### Header 1.1

          ##### Header 1.1.1
        EO_INSTRUCTIONS
        input_artifacts: {}
      )
    ).to eq <<~EO_PROMPT.strip
      # User instructions

      ## Header 1

      ### Header 1.1

      #### Header 1.1.1
    EO_PROMPT
  end
end
