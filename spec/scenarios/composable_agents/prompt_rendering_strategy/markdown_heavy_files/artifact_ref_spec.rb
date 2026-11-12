require 'tmpdir'

describe ComposableAgents::PromptRenderingStrategy::MarkdownHeavyFiles, '#artifact_ref' do
  attr_reader :composable_agents_dir

  around do |example|
    Dir.mktmpdir do |dir|
      @composable_agents_dir = dir
      example.run
    end
  end

  it 'returns the absolute path of an input artifact file' do
    agent = agent_for_markdown_heavy_files(
      composable_agents_dir:,
      input_artifacts_contracts: { plan: 'The plan' }
    )
    expect(agent.artifact_ref(:plan)).to eq(
      File.join(composable_agents_dir, 'artifacts', 'input', 'plan.json')
    )
  end

  it 'returns the absolute path of an output artifact file' do
    agent = agent_for_markdown_heavy_files(
      composable_agents_dir:,
      output_artifacts_contracts: { report: { description: 'The report', type: :text } }
    )
    expect(agent.artifact_ref(:report)).to eq(
      File.join(composable_agents_dir, 'artifacts', 'output', 'report.txt')
    )
  end

  it 'uses the extension corresponding to the artifact type' do
    agent = agent_for_markdown_heavy_files(
      composable_agents_dir:,
      output_artifacts_contracts: {
        json_art: { description: 'JSON artifact', type: :json },
        md_art: { description: 'Markdown artifact', type: :markdown },
        txt_art: { description: 'Text artifact', type: :text },
        default_art: { description: 'Default artifact' }
      }
    )
    output_dir = File.join(composable_agents_dir, 'artifacts', 'output')
    expect(agent.artifact_ref(:json_art)).to eq(File.join(output_dir, 'json_art.json'))
    expect(agent.artifact_ref(:md_art)).to eq(File.join(output_dir, 'md_art.md'))
    expect(agent.artifact_ref(:txt_art)).to eq(File.join(output_dir, 'txt_art.txt'))
    expect(agent.artifact_ref(:default_art)).to eq(File.join(output_dir, 'default_art.json'))
  end

  it 'raises an error for an unknown artifact' do
    agent = agent_for_markdown_heavy_files(composable_agents_dir:)
    expect { agent.artifact_ref(:unknown) }.to raise_error(RuntimeError, 'Unknown artifact: unknown')
  end
end
