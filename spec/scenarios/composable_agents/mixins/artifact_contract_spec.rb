describe ComposableAgents::Mixins::ArtifactContract do
  context 'with input artifacts definitions' do
    let(:agent) do
      Class.new(ComposableAgents::Agent) do
        prepend ComposableAgents::Mixins::ArtifactContract

        attr_reader :received_artifacts

        def input_artifacts_contracts
          {
            first: 'First input artifact',
            second: 'Second input artifact',
            third: 'Third input artifact'
          }
        end

        def output_artifacts_contracts
          {}
        end

        # Run the agent with a set of input artifacts and get the corresponding output artifacts.
        #
        # @param input_artifacts [Hash<Symbol,Object>] The input artifacts content
        # @return Hash<Symbol,Object> Output artifacts content
        def run(**input_artifacts)
          @received_artifacts = input_artifacts
        end
      end.new
    end

    it 'validates all input artifacts' do
      agent.run(first: 10, second: 20, third: 30)
      expect(agent.received_artifacts).to eq({ first: 10, second: 20, third: 30 })
    end

    it 'filters extra input artifacts not defined in input_artifacts' do
      agent.run(
        first: 10,
        second: 20,
        third: 30,
        extra_one: 'should be filtered',
        extra_two: 'also filtered'
      )
      expect(agent.received_artifacts).to eq(
        first: 10,
        second: 20,
        third: 30
      )
    end

    it 'raises MissingInputArtifactError when some input artifacts are missing' do
      expect do
        # Only providing 1 out of 3 required artifacts
        agent.run(first: 10)
      end.to(
        raise_error(ComposableAgents::Mixins::ArtifactContract::MissingInputArtifactError) do |error|
          expect(error.message).to include('Missing required input artifacts')
          expect(error.message).not_to include('first')
          expect(error.message).to include('second: Second input artifact')
          expect(error.message).to include('third: Third input artifact')
        end
      )
    end
  end

  context 'with output artifacts definitions' do
    let(:agent) do
      Class.new(ComposableAgents::Agent) do
        prepend ComposableAgents::Mixins::ArtifactContract

        attr_accessor :mocked_output_artifacts

        def input_artifacts_contracts
          {}
        end

        def output_artifacts_contracts
          {
            result_one: 'First output artifact',
            result_two: 'Second output artifact',
            result_three: 'Third output artifact'
          }
        end

        # Run the agent with a set of input artifacts and get the corresponding output artifacts.
        #
        # @param input_artifacts [Hash<Symbol,Object>] The input artifacts content
        # @return Hash<Symbol,Object> Output artifacts content
        def run(**_input_artifacts)
          mocked_output_artifacts
        end
      end.new
    end

    it 'validates all output artifacts' do
      agent.mocked_output_artifacts = { result_one: 'abc', result_two: 'def', result_three: 'ghi' }
      expect(agent.run).to eq({ result_one: 'abc', result_two: 'def', result_three: 'ghi' })
    end

    it 'ignores extra output artifacts' do
      agent.mocked_output_artifacts = { result_one: 'abc', result_two: 'def', result_three: 'ghi', result_four: 'jkl' }
      expect(agent.run).to eq({ result_one: 'abc', result_two: 'def', result_three: 'ghi', result_four: 'jkl' })
    end

    it 'raises MissingOutputArtifactError when some output artifacts are missing' do
      # Returning only 1 out of 3 expected outputs
      agent.mocked_output_artifacts = { result_one: 'abc' }

      expect do
        agent.run
      end.to(
        raise_error(ComposableAgents::Mixins::ArtifactContract::MissingOutputArtifactError) do |error|
          expect(error.message).to include('Agent failed to produce expected output artifacts')
          expect(error.message).not_to include('result_one')
          expect(error.message).to include('result_two: Second output artifact')
          expect(error.message).to include('result_three: Third output artifact')
        end
      )
    end
  end
end
