require 'tmpdir'

describe ComposableAgents::PromptRenderingStrategy::MarkdownHeavyFiles, '#missing_output_user_instructions' do
  attr_reader :composable_agents_dir

  around do |example|
    Dir.mktmpdir do |dir|
      @composable_agents_dir = dir
      example.run
    end
  end

  it 'prompts for missing artifacts with their absolute file paths' do
    agent = agent_for_markdown_heavy_files(
      composable_agents_dir:,
      output_artifacts_contracts: {
        report: { description: 'Final report document' },
        summary: { description: 'Executive summary', type: :text }
      }
    )
    report_path = File.join(composable_agents_dir, 'artifacts', 'output', 'report.json')
    summary_path = File.join(composable_agents_dir, 'artifacts', 'output', 'summary.txt')
    expect(
      agent.missing_output_user_instructions(
        report: { description: 'Final report document' },
        summary: { description: 'Executive summary' }
      )
    ).to eq <<~EO_PROMPT
      The following output artifacts are missing from your previous responses:
      - `#{report_path}`: Final report document
      - `#{summary_path}`: Executive summary

      You must write each one of them to its expected file path (the absolute paths given above) in your next response (MANDATORY).
    EO_PROMPT
  end

  it 'includes error information when artifacts have errors' do
    agent = agent_for_markdown_heavy_files(
      composable_agents_dir:,
      output_artifacts_contracts: {
        report: { description: 'Final report document' },
        summary: { description: 'Executive summary', type: :text }
      }
    )
    report_path = File.join(composable_agents_dir, 'artifacts', 'output', 'report.json')
    summary_path = File.join(composable_agents_dir, 'artifacts', 'output', 'summary.txt')
    expect(
      agent.missing_output_user_instructions(
        report: { description: 'Final report document', error: 'File not found' },
        summary: { description: 'Executive summary' }
      )
    ).to eq <<~EO_PROMPT
      The following output artifacts are missing from your previous responses:
      - `#{report_path}`: Final report document
        An error occurred while reading this artifact from your previous responses: File not found
      - `#{summary_path}`: Executive summary

      You must write each one of them to its expected file path (the absolute paths given above) in your next response (MANDATORY).
    EO_PROMPT
  end
end
