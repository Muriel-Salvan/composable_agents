require 'tmpdir'

describe ComposableAgents::PromptRenderingStrategy::MarkdownHeavyFiles, '#initialize' do
  attr_reader :composable_agents_dir

  around do |example|
    Dir.mktmpdir do |dir|
      @composable_agents_dir = dir
      example.run
    end
  end

  # Define an agent that writes its output artifacts to their expected file paths
  # and reports the path it used, so that the strategy's public interface can be exercised.
  let(:agent_class) do
    Class.new(ComposableAgents::PromptDrivenAgent) do
      prepend ComposableAgents::Mixins::ArtifactContract
      include ComposableAgents::PromptRenderingStrategy::MarkdownHeavyFiles

      # @return [String, nil] The path where the result artifact was written
      attr_accessor :written_result_path

      # Define the input artifacts contracts expected by this test agent.
      #
      # @return [Hash{Symbol => Object}] The input artifacts contracts, per artifact name
      def input_artifacts_contracts
        { note: { description: 'A note', type: :text } }
      end

      # Define the output artifacts contracts produced by this test agent.
      #
      # @return [Hash{Symbol => Object}] The output artifacts contracts, per artifact name
      def output_artifacts_contracts
        { result: { description: 'A result', type: :text } }
      end

      # Write the result artifact to its expected file and read it back as an output artifact.
      #
      # @param _user_prompt [String] The rendered user prompt (unused)
      # @return [String] The assistant response
      def prompt(_user_prompt)
        self.written_result_path = artifact_ref(:result)
        File.write(written_result_path, 'My result content')
        parse_output_artifacts('assistant response is ignored')
        'assistant response is ignored'
      end
    end
  end

  it 'writes input artifacts to and reads output artifacts from the default artifacts directory' do
    agent = agent_class.new(composable_agents_dir:)
    expect(agent.run(note: 'My note')).to eq(result: 'My result content')
    expect(File.read(File.join(composable_agents_dir, 'artifacts', 'input', 'note.txt'))).to eq('My note')
    expect(agent.written_result_path).to eq(File.join(composable_agents_dir, 'artifacts', 'output', 'result.txt'))
  end

  it 'writes input artifacts to and reads output artifacts from a custom artifacts directory' do
    custom_dir = File.join(composable_agents_dir, 'custom_artifacts')
    agent = agent_class.new(composable_agents_dir:, artifacts_directory: custom_dir)
    expect(agent.run(note: 'My note')).to eq(result: 'My result content')
    expect(File.read(File.join(custom_dir, 'input', 'note.txt'))).to eq('My note')
    expect(agent.written_result_path).to eq(File.join(custom_dir, 'output', 'result.txt'))
  end

  it 'creates the input and output artifacts directories' do
    agent_class.new(composable_agents_dir:)
    expect(File).to be_directory(File.join(composable_agents_dir, 'artifacts', 'input'))
    expect(File).to be_directory(File.join(composable_agents_dir, 'artifacts', 'output'))
  end
end
