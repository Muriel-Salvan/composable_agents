require 'json'

describe ComposableAgents::PromptRenderingStrategy::MarkdownHeavy, '#render_user_prompt' do
  it 'returns only the user instructions section when context and input artifacts are empty' do
    expect(agent_for_markdown_heavy.render_user_prompt('Hello, I need assistance')).to eq <<~EO_PROMPT.strip
      # User instructions

      Hello, I need assistance
    EO_PROMPT
  end

  it 'handles nil rendered instructions with no context or artifacts' do
    expect(agent_for_markdown_heavy.render_user_prompt(nil)).to eq('')
  end

  it 'handles empty rendered instructions with no context or artifacts' do
    expect(agent_for_markdown_heavy.render_user_prompt('')).to eq('')
  end

  it 'includes previous sessions context when @context is set' do
    expect(
      agent_for_markdown_heavy(context: { 'previous_task' => 'analyzed data', 'findings' => %w[item1 item2] })
        .render_user_prompt('Continue with the task')
    ).to eq <<~EO_PROMPT.strip
      # Previous sessions context

      Here is the conversation from a previous session for context:

      ```json
      {"previous_task":"analyzed data","findings":["item1","item2"]}
      ```

      Continue with the task, building on the work from the session above.

      # User instructions

      Continue with the task
    EO_PROMPT
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

  it 'includes both context and input artifacts sections when both are present' do
    expect(
      agent_for_markdown_heavy(context: { 'session' => 1, 'progress' => '50%' }).render_user_prompt(
        'Please finish the task',
        input_artifacts: {
          plan: 'Complete the report',
          draft: 'Partial draft content'
        }
      )
    ).to eq <<~EO_PROMPT.strip
      # Previous sessions context

      Here is the conversation from a previous session for context:

      ```json
      {"session":1,"progress":"50%"}
      ```

      Continue with the task, building on the work from the session above.

      # Input artifacts

      ## `ARTIFACT_PLAN`

      ```json input_artifact=ARTIFACT_PLAN
      "Complete the report"
      ```

      ## `ARTIFACT_DRAFT`

      ```json input_artifact=ARTIFACT_DRAFT
      "Partial draft content"
      ```

      # User instructions

      Please finish the task
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

  it 'handles context without rendered instructions' do
    expect(agent_for_markdown_heavy(context: { 'id' => 42 }).render_user_prompt(nil)).to eq <<~EO_PROMPT.strip
      # Previous sessions context

      Here is the conversation from a previous session for context:

      ```json
      {"id":42}
      ```

      Continue with the task, building on the work from the session above.
    EO_PROMPT
  end

  it 'handles empty context hash correctly with artifacts' do
    expect(
      agent_for_markdown_heavy.render_user_prompt(
        'Simple message',
        input_artifacts: {
          doc: 'Some content'
        }
      )
    ).to eq <<~EO_PROMPT.strip
      # Input artifacts

      ## `ARTIFACT_DOC`

      ```json input_artifact=ARTIFACT_DOC
      "Some content"
      ```

      # User instructions

      Simple message
    EO_PROMPT
  end
end
