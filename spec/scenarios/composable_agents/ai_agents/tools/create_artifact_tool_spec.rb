describe ComposableAgents::AiAgents::Tools::CreateArtifactTool do
  subject(:tool) { described_class.new(artifacts) }

  let(:tool_context) { instance_double(Agents::ToolContext) }
  let(:artifacts) { {} }

  describe '#perform' do
    context 'when creating a new artifact' do
      it 'stores the artifact in the artifacts hash with symbolized key' do
        tool.perform(tool_context, name: 'test_artifact', content: 'test content')
        expect(artifacts[:test_artifact]).to eq('test content')
      end

      it 'returns success message' do
        expect(
          tool.perform(tool_context, name: 'test_artifact', content: 'test content')
        ).to eq('Artifact `test_artifact` created successfully.')
      end
    end

    context 'when overwriting an existing artifact' do
      before { artifacts[:existing_artifact] = 'old content' }

      it 'replaces the existing artifact content' do
        tool.perform(tool_context, name: 'existing_artifact', content: 'new content')
        expect(artifacts[:existing_artifact]).to eq('new content')
      end

      it 'returns success message' do
        expect(
          tool.perform(tool_context, name: 'existing_artifact', content: 'new content')
        ).to eq('Artifact `existing_artifact` created successfully.')
      end
    end
  end
end
