RSpec.describe ComposableAgents::Agent do
  context 'when instantiated directly' do
    let(:agent) { described_class.new }

    context 'without a name' do
      it 'returns a default unnamed agent' do
        expect(agent.full_name).to eq('Unnamed')
      end
    end

    context 'with a name' do
      let(:agent) { described_class.new(name: 'MyAgent') }

      it 'returns just the name without the class in parentheses' do
        expect(agent.full_name).to eq('MyAgent')
      end
    end
  end

  context 'when instantiated with an unnamed subclass' do
    let(:subclass) do
      Class.new(described_class)
    end

    context 'without a name' do
      let(:agent) { subclass.new }

      it 'returns only the unnamed name' do
        expect(agent.full_name).to eq('Unnamed')
      end
    end

    context 'with a name' do
      let(:agent) { subclass.new(name: 'MySubAgent') }

      it 'returns the name without the unnamed subclass name in parentheses' do
        expect(agent.full_name).to eq('MySubAgent')
      end
    end
  end

  context 'when instantiated with a named subclass' do
    let(:subclass) do
      Class.new(described_class)
    end

    before do
      singleton_class.const_set(:TestAgent, subclass)
    end

    context 'without a name' do
      let(:agent) { subclass.new }

      it 'returns the class name in parentheses with an empty name' do
        expect(agent.full_name).to eq('Unnamed (TestAgent)')
      end
    end

    context 'with a name' do
      let(:agent) { subclass.new(name: 'MySubAgent') }

      it 'returns the name with the subclass name in parentheses' do
        expect(agent.full_name).to eq('MySubAgent (TestAgent)')
      end
    end
  end
end
