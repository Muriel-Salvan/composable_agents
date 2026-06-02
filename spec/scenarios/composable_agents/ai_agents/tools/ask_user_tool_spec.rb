describe ComposableAgents::AiAgents::Tools::AskUserTool do
  subject(:tool) { described_class.new(agent) }

  let(:tool_context) { instance_double(Agents::ToolContext) }
  let(:agent) do
    Class.new(ComposableAgents::AiAgents::Agent) do
      prepend ComposableAgents::Mixins::AiAgentUserInteraction

      attr_reader :received_question

      private

      def answer_to(question)
        @received_question = question
        'The answer is 42'
      end
    end.new
  end

  describe '#perform' do
    it 'delegates to agent#ask with the given question' do
      expect(tool.perform(tool_context, question: 'Life meaning?')).to eq('The answer is 42')
      expect(agent.received_question).to eq 'Life meaning?'
    end
  end
end
