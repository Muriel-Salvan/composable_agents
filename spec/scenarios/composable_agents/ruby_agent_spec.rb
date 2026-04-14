describe ComposableAgents::RubyAgent do
  it 'executes the provided proc correctly' do
    execution_flag = false
    described_class.new(proc do
      execution_flag = true
      {}
    end).run
    expect(execution_flag).to be(true)
  end

  it 'receives input artifacts' do
    expected_artifacts = {
      artifact1: 1,
      artifact2: 2
    }
    received_artifacts = nil
    described_class.new(proc do |input_artifacts|
      received_artifacts = input_artifacts
      {}
    end).run(input_artifacts: expected_artifacts)
    expect(received_artifacts).to eq expected_artifacts
  end

  it 'returns output artifacts' do
    expected_artifacts = {
      artifact1: 1,
      artifact2: 2
    }
    expect(described_class.new(proc { expected_artifacts }).run).to eq expected_artifacts
  end

  it 'exposes name attribute' do
    test_name = 'test_ruby_agent'
    expect(described_class.new(proc {}, name: test_name).name).to eq(test_name)
  end

  it 'handles nil name correctly' do
    expect(described_class.new(proc {}, name: nil).name).to be_nil
  end
end
