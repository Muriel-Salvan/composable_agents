RSpec.describe ComposableAgents::Agent, '#runs_info' do
  let(:agent) { described_class.new }

  context 'when no run happened' do
    it 'returns an empty array' do
      expect(agent.runs_info).to eq([])
    end
  end

  context 'when 1 run happened' do
    # Fixed timestamp used to mock Time.now, so that the started_at property is deterministic.
    let(:started_at) { Time.new(2026, 9, 4, 10, 30, 0, '+00:00') }

    before do
      allow(Time).to receive(:now).and_return(started_at)
      agent.run
    end

    it 'contains 1 run info entry' do
      expect(agent.runs_info.size).to eq(1)
    end

    it 'contains the started_at timestamp' do
      expect(agent.runs_info.first.started_at).to eq(started_at)
    end
  end

  context 'when calling run multiple times' do
    # Fixed timestamps used to mock Time.now sequentially, so that each run gets a different started_at.
    let(:started_at_sequence) do
      [
        Time.new(2026, 9, 4, 10, 30, 0, '+00:00'),
        Time.new(2026, 9, 4, 10, 30, 1, '+00:00'),
        Time.new(2026, 9, 4, 10, 30, 2, '+00:00')
      ]
    end

    before do
      allow(Time).to receive(:now).and_return(*started_at_sequence)
      3.times { agent.run }
    end

    it 'contains 3 run info entries' do
      expect(agent.runs_info.size).to eq(3)
    end

    it 'contains different started_at timestamps for each run' do
      expect(agent.runs_info.map(&:started_at)).to eq(started_at_sequence)
    end
  end

  context 'when a subclass publishes additional run info' do
    let(:subclass) do
      Class.new(described_class) do
        def run(**input_artifacts)
          super
          publish_run_info(custom_property: 'custom_value')
          {}
        end
      end
    end

    let(:agent) { subclass.new }

    # Fixed timestamp used to mock Time.now, so that the started_at property is deterministic.
    let(:started_at) { Time.new(2026, 9, 4, 10, 30, 0, '+00:00') }

    before do
      allow(Time).to receive(:now).and_return(started_at)
      agent.run
    end

    it 'contains 1 run info entry' do
      expect(agent.runs_info.size).to eq(1)
    end

    it 'contains the started_at timestamp' do
      expect(agent.runs_info.first.started_at).to eq(started_at)
    end

    it 'contains the custom published property alongside started_at' do
      expect(agent.runs_info.first.custom_property).to eq('custom_value')
    end
  end
end
