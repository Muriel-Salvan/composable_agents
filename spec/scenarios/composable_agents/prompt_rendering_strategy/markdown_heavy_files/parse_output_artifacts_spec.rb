require 'tmpdir'
require 'json'

describe ComposableAgents::PromptRenderingStrategy::MarkdownHeavyFiles, '#parse_output_artifacts' do
  attr_reader :composable_agents_dir

  around do |example|
    Dir.mktmpdir do |dir|
      @composable_agents_dir = dir
      example.run
    end
  end

  let(:output_contracts) { {} }
  let!(:agent) do
    new_agent = agent_for_markdown_heavy_files(
      composable_agents_dir:,
      output_artifacts_contracts: output_contracts
    )
    new_agent.output_artifacts = {}
    new_agent.output_artifacts_errors = {}
    new_agent
  end

  # Get the directory where this strategy persists its output artifacts on disk.
  # This directory is created lazily by the strategy, so it is created here to simulate the assistant
  # writing its output artifacts to the paths it was given.
  #
  # @return [String] The absolute path of the output artifacts directory
  def output_dir
    File.join(composable_agents_dir, 'artifacts', 'output').tap { |dir| FileUtils.mkdir_p(dir) }
  end

  describe 'with 1 output artifact not having type information' do
    let(:output_contracts) { { report: { description: 'Final report' } } }

    it 'parses the artifact correctly from its JSON file' do
      File.write(File.join(output_dir, 'report.json'), '{"title":"My Report","section":"Introduction"}')
      agent.parse_output_artifacts('The assistant response text is ignored')
      expect(agent.output_artifacts).to eq(report: { 'title' => 'My Report', 'section' => 'Introduction' })
      expect(agent.output_artifacts_errors).to be_empty
    end

    it 'reports the error correctly when JSON cannot be parsed' do
      File.write(File.join(output_dir, 'report.json'), 'not valid json')
      agent.parse_output_artifacts('ignored')
      expect(agent.output_artifacts).to be_empty
      expect(agent.output_artifacts_errors[:report]).to include('unexpected token')
    end
  end

  describe 'with 1 output artifact of type text' do
    let(:output_contracts) { { result: { description: 'Text result', type: :text } } }

    it 'parses the artifact correctly' do
      File.write(File.join(output_dir, 'result.txt'), 'My text result')
      agent.parse_output_artifacts('ignored')
      expect(agent.output_artifacts).to eq(result: 'My text result')
      expect(agent.output_artifacts_errors).to be_empty
    end
  end

  describe 'with 1 output artifact of type markdown' do
    let(:output_contracts) { { doc: { description: 'Markdown document', type: :markdown } } }

    it 'parses the artifact correctly' do
      File.write(File.join(output_dir, 'doc.md'), "# Title\n\nBody text")
      agent.parse_output_artifacts('ignored')
      expect(agent.output_artifacts).to eq(doc: "# Title\n\nBody text")
      expect(agent.output_artifacts_errors).to be_empty
    end
  end

  describe 'with several output artifacts of various types' do
    let(:output_contracts) do
      {
        report: { description: 'Text report', type: :text },
        doc: { description: 'Markdown doc', type: :markdown },
        data: { description: 'JSON data', type: :json },
        blob: { description: 'Any data' }
      }
    end

    it 'parses all of them from their files' do
      File.write(File.join(output_dir, 'report.txt'), 'The report content')
      File.write(File.join(output_dir, 'doc.md'), '## Document')
      File.write(File.join(output_dir, 'data.json'), '{"key": "value"}')
      File.write(File.join(output_dir, 'blob.json'), '42')
      agent.parse_output_artifacts('ignored')
      expect(agent.output_artifacts).to eq(
        report: 'The report content',
        doc: '## Document',
        data: { 'key' => 'value' },
        blob: 42
      )
      expect(agent.output_artifacts_errors).to be_empty
    end

    it 'ignores missing files' do
      agent.parse_output_artifacts('ignored')
      expect(agent.output_artifacts).to be_empty
      expect(agent.output_artifacts_errors).to be_empty
    end
  end
end
