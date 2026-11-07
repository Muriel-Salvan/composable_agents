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
      {
        "amount": 50000,
        "currency": "EUR"
      }
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

  it 'pretty-prints input artifacts JSON so that no line is too long' do
    plan = {
      title: 'Build a house',
      steps: (1..20).map { |step_idx| { step: step_idx, action: "Action #{step_idx}", done: step_idx.even? } }
    }
    rendered_prompt = agent_for_markdown_heavy.render_user_prompt(nil, input_artifacts: { plan: })
    # The JSON block is pretty-printed, so no line exceeds the limits of harnesses truncating them
    expect(rendered_prompt.lines.map { |line| line.chomp.length }.max).to be < 100
    # The JSON content still holds the artifact content
    json_block = rendered_prompt.scan(/^```json input_artifact=ARTIFACT_PLAN\n(.*?)^```/m).last.first
    expect(JSON.parse(json_block)).to eq(JSON.parse(JSON.generate(plan)))
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

  it 'serializes text input artifacts as lines and adds the serialization format description' do
    expect(
      agent_for_markdown_heavy(input_artifacts_contracts: { report: { description: 'The report', type: :text } }).render_user_prompt(
        nil,
        input_artifacts: { report: "Line 1\nLine 2" }
      )
    ).to eq <<~EO_PROMPT.strip
      # Input artifacts

      Artifact serialization format:

      An artifact with type "markdown" represents exactly one Markdown document.
      Its "lines" property is an ordered array of strings representing the
      document's lines.

      Reconstruct the document by joining the elements with LF (\\n).
      Empty strings represent empty lines.

      Preserve all content exactly, including whitespace and indentation.
      Treat the reconstructed document as a single artifact.

      ## `ARTIFACT_REPORT`

      ```json input_artifact=ARTIFACT_REPORT
      {
        "type": "text",
        "lines": [
          "Line 1",
          "Line 2"
        ]
      }
      ```
    EO_PROMPT
  end

  it 'serializes markdown input artifacts as lines' do
    expect(
      agent_for_markdown_heavy(input_artifacts_contracts: { doc: { description: 'The document', type: :markdown } }).render_user_prompt(
        nil,
        input_artifacts: { doc: "# Title\n\nBody" }
      )
    ).to eq <<~EO_PROMPT.strip
      # Input artifacts

      Artifact serialization format:

      An artifact with type "markdown" represents exactly one Markdown document.
      Its "lines" property is an ordered array of strings representing the
      document's lines.

      Reconstruct the document by joining the elements with LF (\\n).
      Empty strings represent empty lines.

      Preserve all content exactly, including whitespace and indentation.
      Treat the reconstructed document as a single artifact.

      ## `ARTIFACT_DOC`

      ```json input_artifact=ARTIFACT_DOC
      {
        "type": "markdown",
        "lines": [
          "# Title",
          "",
          "Body"
        ]
      }
      ```
    EO_PROMPT
  end

  it 'does not add the serialization format description for json-only input artifacts' do
    expect(
      agent_for_markdown_heavy(input_artifacts_contracts: { data: { description: 'The data', type: :json } }).render_user_prompt(
        nil,
        input_artifacts: { data: { 'key' => 'value' } }
      )
    ).to eq <<~EO_PROMPT.strip
      # Input artifacts

      ## `ARTIFACT_DATA`

      ```json input_artifact=ARTIFACT_DATA
      {
        "key": "value"
      }
      ```
    EO_PROMPT
  end

  it 'raises when an input artifact has an unknown type' do
    expect do
      agent_for_markdown_heavy(input_artifacts_contracts: { weird: { description: 'The weird artifact', type: :unknown } })
        .render_user_prompt(nil, input_artifacts: { weird: 'content' })
    end.to raise_error(RuntimeError, /Unknown artifact type: unknown/)
  end
end
