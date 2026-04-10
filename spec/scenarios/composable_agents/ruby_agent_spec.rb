require 'composable_agents/ruby_agent'

describe ComposableAgents::RubyAgent do
  describe '#safe_run' do
    it 'executes the provided proc correctly' do
      execution_flag = false
      described_class.new(proc do
        execution_flag = true
        {}
      end).safe_run
      expect(execution_flag).to be(true)
    end
  end

  context 'with subclass defining input artifacts' do
    let(:input_agent_class) do
      Class.new(described_class) do
        input_artifacts(
          first: 'First input artifact',
          second: 'Second input artifact',
          third: 'Third input artifact'
        )
      end
    end

    it 'passes all input artifacts correctly to the proc' do
      received_artifacts = nil
      input_artifacts = { first: 10, second: 20, third: 30 }
      input_agent_class.new(proc do |artifacts|
        received_artifacts = artifacts
        {}
      end).safe_run(input_artifacts:)
      expect(received_artifacts).to eq(input_artifacts)
    end

    it 'raises MissingInputArtifactError when some input artifacts are missing' do
      agent = input_agent_class.new(->(_) { {} })

      expect do
        # Only providing 1 out of 3 required artifacts
        agent.safe_run(input_artifacts: { first: 10 })
      end.to(
        raise_error(ComposableAgents::MissingInputArtifactError) do |error|
          expect(error.message).to include('Missing required input artifacts')
          expect(error.message).not_to include('first')
          expect(error.message).to include('second: Second input artifact')
          expect(error.message).to include('third: Third input artifact')
        end
      )
    end
  end

  context 'with subclass defining output artifacts' do
    let(:output_agent_class) do
      Class.new(described_class) do
        output_artifacts(
          result_one: 'First output artifact',
          result_two: 'Second output artifact',
          result_three: 'Third output artifact'
        )
      end
    end

    it 'returns the output artifacts produced by the proc' do
      output_artifacts = { result_one: 'abc', result_two: 'def', result_three: 'ghi' }
      expect(output_agent_class.new(->(_) { output_artifacts }).safe_run).to eq(output_artifacts)
    end

    it 'raises MissingOutputArtifactError when some output artifacts are missing' do
      # Returning only 1 out of 3 expected outputs
      agent = output_agent_class.new(->(_) { { result_one: 'abc' } })

      expect do
        agent.safe_run
      end.to(
        raise_error(ComposableAgents::MissingOutputArtifactError) do |error|
          expect(error.message).to include('Agent failed to produce expected output artifacts')
          expect(error.message).not_to include('result_one')
          expect(error.message).to include('result_two: Second output artifact')
          expect(error.message).to include('result_three: Third output artifact')
        end
      )
    end
  end
end
