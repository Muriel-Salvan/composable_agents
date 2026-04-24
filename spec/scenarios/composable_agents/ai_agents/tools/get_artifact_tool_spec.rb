describe ComposableAgents::AiAgents::Tools::GetArtifactTool do
  subject(:tool) { described_class.new(artifacts) }

  let(:tool_context) { instance_double(Agents::ToolContext) }
  let(:artifacts) { {} }

  describe '#perform' do
    context 'when artifact exists' do
      it 'returns the artifact content' do
        artifacts[:test_artifact] = 'test content'
        expect(tool.perform(tool_context, name: 'test_artifact')).to eq('test content')
      end

      it 'converts non-string content to string' do
        artifacts[:number_artifact] = 12_345
        expect(tool.perform(tool_context, name: 'number_artifact')).to eq('12345')
      end
    end

    context 'when artifact does not exist' do
      it 'returns error message' do
        result = tool.perform(tool_context, name: 'non_existent')
        expect(result).to eq("[ERROR] No artifact named non_existent, don't call this tool with the name non_existent anymore.")
      end
    end
  end
end
