require 'tmpdir'
require 'json'

describe ComposableAgents::PromptRenderingStrategy::MarkdownHeavyFiles, '#render_user_prompt' do
  attr_reader :composable_agents_dir

  around do |example|
    Dir.mktmpdir do |dir|
      @composable_agents_dir = dir
      example.run
    end
  end

  it 'returns only the user instructions section when input artifacts are empty' do
    expect(
      agent_for_markdown_heavy_files(composable_agents_dir:).render_user_prompt('Hello, I need assistance', input_artifacts: {})
    ).to eq <<~EO_PROMPT.strip
      # User instructions

      Hello, I need assistance
    EO_PROMPT
  end

  it 'handles nil rendered instructions with no artifacts' do
    expect(agent_for_markdown_heavy_files(composable_agents_dir:).render_user_prompt(nil, input_artifacts: {})).to eq('')
  end

  it 'handles empty rendered instructions with no artifacts' do
    expect(agent_for_markdown_heavy_files(composable_agents_dir:).render_user_prompt('', input_artifacts: {})).to eq('')
  end

  it 'persists input artifacts as files and references their absolute paths' do
    agent = agent_for_markdown_heavy_files(
      composable_agents_dir:,
      input_artifacts_contracts: {
        plan: 'The plan',
        budget: { description: 'The budget', type: :json }
      }
    )
    plan_path = File.join(composable_agents_dir, 'artifacts', 'input', 'plan.json')
    budget_path = File.join(composable_agents_dir, 'artifacts', 'input', 'budget.json')
    expect(
      agent.render_user_prompt(
        'Process these documents',
        input_artifacts: { plan: 'Build a house', budget: { amount: 50_000, currency: 'EUR' } }
      )
    ).to eq <<~EO_PROMPT.strip
      # Input artifacts

      The following input artifacts are persisted as files on disk. Open and read each file whenever you need the corresponding input artifact content:

      ## `#{plan_path}`

      - Open and read the file `#{plan_path}` whenever you need the corresponding input artifact content.

      ## `#{budget_path}`

      - Open and read the file `#{budget_path}` whenever you need the corresponding input artifact content.

      # User instructions

      Process these documents
    EO_PROMPT
    expect(JSON.parse(File.read(plan_path))).to eq('Build a house')
    expect(JSON.parse(File.read(budget_path))).to eq('amount' => 50_000, 'currency' => 'EUR')
  end

  it 'persists text and markdown input artifacts using their raw content' do
    agent = agent_for_markdown_heavy_files(
      composable_agents_dir:,
      input_artifacts_contracts: {
        notes: { description: 'The notes', type: :text },
        doc: { description: 'The document', type: :markdown }
      }
    )
    agent.render_user_prompt(nil, input_artifacts: { notes: "Line 1\nLine 2", doc: "# Title\n\nBody" })
    notes_path = File.join(composable_agents_dir, 'artifacts', 'input', 'notes.txt')
    doc_path = File.join(composable_agents_dir, 'artifacts', 'input', 'doc.md')
    expect(File.read(notes_path)).to eq("Line 1\nLine 2")
    expect(File.read(doc_path)).to eq("# Title\n\nBody")
  end

  it 'raises when an input artifact has an unknown type' do
    expect do
      agent_for_markdown_heavy_files(
        composable_agents_dir:,
        input_artifacts_contracts: { weird: { description: 'The weird artifact', type: :unknown } }
      ).render_user_prompt(nil, input_artifacts: { weird: 'content' })
    end.to raise_error(RuntimeError, /Unknown artifact type: unknown/)
  end
end
