require 'tmpdir'

describe ComposableAgents::PromptRenderingStrategy::MarkdownHeavyFiles, '#artifacts_directory' do
  attr_reader :composable_agents_dir

  around do |example|
    Dir.mktmpdir do |dir|
      @composable_agents_dir = dir
      example.run
    end
  end

  # Define an agent that writes its output artifacts to their expected file paths
  # and reports the path it used, so that the strategy's public interface can be exercised.
  #
  # @return [Class] The corresponding agent class
  def test_agent_class
    Class.new(ComposableAgents::PromptDrivenAgent) do
      prepend ComposableAgents::Mixins::ArtifactContract

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

  # Instantiate the test agent, giving it this strategy through its constructor
  # (strategies are installed by the agent's constructor, and are configured through the accessors they expose).
  #
  # @return [ComposableAgents::PromptDrivenAgent] The test agent, using this strategy
  def new_agent
    test_agent_class.new(composable_agents_dir:, strategy: described_class)
  end

  it 'defaults to the artifacts directory of the agent' do
    expect(new_agent.artifacts_directory).to eq File.join(composable_agents_dir, 'artifacts')
  end

  it 'writes input artifacts to and reads output artifacts from the default artifacts directory' do
    agent = new_agent
    expect(agent.run(note: 'My note')).to eq(result: 'My result content')
    expect(File.read(File.join(composable_agents_dir, 'artifacts', 'input', 'note.txt'))).to eq('My note')
    expect(agent.written_result_path).to eq(File.join(composable_agents_dir, 'artifacts', 'output', 'result.txt'))
  end

  it 'writes input artifacts to and reads output artifacts from a custom artifacts directory' do
    custom_dir = File.join(composable_agents_dir, 'custom_artifacts')
    agent = new_agent
    agent.artifacts_directory = custom_dir
    expect(agent.artifacts_directory).to eq custom_dir
    expect(agent.run(note: 'My note')).to eq(result: 'My result content')
    expect(File.read(File.join(custom_dir, 'input', 'note.txt'))).to eq('My note')
    expect(agent.written_result_path).to eq(File.join(custom_dir, 'output', 'result.txt'))
  end

  it 'falls back to the default artifacts directory when set to nil' do
    agent = new_agent
    agent.artifacts_directory = File.join(composable_agents_dir, 'custom_artifacts')
    agent.artifacts_directory = nil
    expect(agent.artifacts_directory).to eq File.join(composable_agents_dir, 'artifacts')
  end

  it 'creates the input and output artifacts directories when they are first needed' do
    agent = new_agent
    expect(File).not_to be_directory(File.join(composable_agents_dir, 'artifacts', 'input'))
    expect(File).not_to be_directory(File.join(composable_agents_dir, 'artifacts', 'output'))
    agent.artifact_ref(:note)
    expect(File).to be_directory(File.join(composable_agents_dir, 'artifacts', 'input'))
    expect(File).not_to be_directory(File.join(composable_agents_dir, 'artifacts', 'output'))
    agent.artifact_ref(:result)
    expect(File).to be_directory(File.join(composable_agents_dir, 'artifacts', 'output'))
  end

  it 'uses the new artifacts directory when it is changed after artifacts were already persisted' do
    new_dir = File.join(composable_agents_dir, 'new_artifacts')
    agent = new_agent
    expect(agent.run(note: 'First note')).to eq(result: 'My result content')
    agent.artifacts_directory = new_dir
    expect(agent.run(note: 'Second note')).to eq(result: 'My result content')
    expect(File.read(File.join(new_dir, 'input', 'note.txt'))).to eq('Second note')
    expect(agent.written_result_path).to eq(File.join(new_dir, 'output', 'result.txt'))
  end
end
