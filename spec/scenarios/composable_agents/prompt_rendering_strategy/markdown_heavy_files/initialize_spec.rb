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
  #
  # @param include_strategy [Boolean] Should the strategy be included in the agent's class (true),
  #   or should it be given by the strategy constructor parameter (false)?
  # @return [Class] The corresponding agent class
  def test_agent_class(include_strategy: true)
    strategy = described_class
    Class.new(ComposableAgents::PromptDrivenAgent) do
      prepend ComposableAgents::Mixins::ArtifactContract
      include strategy if include_strategy

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

  let(:agent_class) { test_agent_class }

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

  it 'creates the input and output artifacts directories when they are first needed' do
    agent = agent_class.new(composable_agents_dir:)
    expect(File).not_to be_directory(File.join(composable_agents_dir, 'artifacts', 'input'))
    expect(File).not_to be_directory(File.join(composable_agents_dir, 'artifacts', 'output'))
    agent.artifact_ref(:note)
    expect(File).to be_directory(File.join(composable_agents_dir, 'artifacts', 'input'))
    expect(File).not_to be_directory(File.join(composable_agents_dir, 'artifacts', 'output'))
    agent.artifact_ref(:result)
    expect(File).to be_directory(File.join(composable_agents_dir, 'artifacts', 'output'))
  end

  # Agents using a prompt rendering strategy give it to their constructor using the strategy parameter
  # instead of including it in their class (see ComposableAgents::Cline::Agent#initialize).
  # The strategy's constructor must consequently be called on this path too, so that its state is initialized.
  describe 'when the strategy is given by the strategy constructor parameter' do
    let(:agent_class) { test_agent_class(include_strategy: false) }

    # Instantiate the test agent, giving it the strategy through its constructor.
    #
    # @return [ComposableAgents::PromptDrivenAgent] The test agent, using this strategy
    def new_agent
      agent_class.new(composable_agents_dir:, strategy: described_class)
    end

    it 'returns the absolute paths of input and output artifacts' do
      agent = new_agent
      expect(agent.artifact_ref(:note)).to eq File.join(composable_agents_dir, 'artifacts', 'input', 'note.txt')
      expect(agent.artifact_ref(:result)).to eq File.join(composable_agents_dir, 'artifacts', 'output', 'result.txt')
      expect(File).to be_directory(File.join(composable_agents_dir, 'artifacts', 'input'))
      expect(File).to be_directory(File.join(composable_agents_dir, 'artifacts', 'output'))
    end

    it 'writes input artifacts to and reads output artifacts from the default artifacts directory' do
      agent = new_agent
      expect(agent.run(note: 'My note')).to eq(result: 'My result content')
      expect(File.read(File.join(composable_agents_dir, 'artifacts', 'input', 'note.txt'))).to eq('My note')
      expect(agent.written_result_path).to eq(File.join(composable_agents_dir, 'artifacts', 'output', 'result.txt'))
    end
  end
end
