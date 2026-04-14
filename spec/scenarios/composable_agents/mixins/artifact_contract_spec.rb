describe ComposableAgents::Mixins::ArtifactContract do
  context 'with subclass defining input artifacts' do
    let(:input_agent_class) do
      Class.new(ComposableAgents::RubyAgent) do
        prepend ComposableAgents::Mixins::ArtifactContract

        input_artifacts(
          first: 'First input artifact',
          second: 'Second input artifact',
          third: 'Third input artifact'
        )
      end
    end

    it 'validates all input artifacts' do
      received_artifacts = nil
      input_artifacts = { first: 10, second: 20, third: 30 }
      input_agent_class.new(proc do |artifacts|
        received_artifacts = artifacts
        {}
      end).run(input_artifacts:)
      expect(received_artifacts).to eq(input_artifacts)
    end

    it 'filters extra input artifacts not defined in input_artifacts' do
      received_artifacts = nil
      input_artifacts = {
        first: 10,
        second: 20,
        third: 30,
        extra_one: 'should be filtered',
        extra_two: 'also filtered'
      }
      input_agent_class.new(proc do |artifacts|
        received_artifacts = artifacts
        {}
      end).run(input_artifacts:)
      expect(received_artifacts).to eq(
        first: 10,
        second: 20,
        third: 30
      )
    end

    it 'raises MissingInputArtifactError when some input artifacts are missing' do
      agent = input_agent_class.new(->(_) { {} })

      expect do
        # Only providing 1 out of 3 required artifacts
        agent.run(input_artifacts: { first: 10 })
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

  context 'with subclass defining input artifacts from parent classes as well' do
    let(:input_agent_class) do
      Class.new(
        Class.new(ComposableAgents::RubyAgent) do
          prepend ComposableAgents::Mixins::ArtifactContract

          input_artifacts(
            first: 'First input artifact',
            second: 'Second input artifact'
          )
        end
      ) do
        prepend ComposableAgents::Mixins::ArtifactContract

        input_artifacts(third: 'Third input artifact')
      end
    end

    it 'validates all input artifacts' do
      received_artifacts = nil
      input_artifacts = { first: 10, second: 20, third: 30 }
      input_agent_class.new(proc do |artifacts|
        received_artifacts = artifacts
        {}
      end).run(input_artifacts:)
      expect(received_artifacts).to eq(input_artifacts)
    end

    it 'filters extra input artifacts not defined in input_artifacts' do
      received_artifacts = nil
      input_artifacts = {
        first: 10,
        second: 20,
        third: 30,
        extra_one: 'should be filtered',
        extra_two: 'also filtered'
      }
      input_agent_class.new(proc do |artifacts|
        received_artifacts = artifacts
        {}
      end).run(input_artifacts:)
      expect(received_artifacts).to eq(
        first: 10,
        second: 20,
        third: 30
      )
    end

    it 'raises MissingInputArtifactError when some input artifacts are missing' do
      agent = input_agent_class.new(->(_) { {} })

      expect do
        # Only providing 1 out of 3 required artifacts
        agent.run(input_artifacts: { first: 10 })
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

  context 'with subclass defining output artifacts' do
    let(:output_agent_class) do
      Class.new(ComposableAgents::RubyAgent) do
        prepend ComposableAgents::Mixins::ArtifactContract

        output_artifacts(
          result_one: 'First output artifact',
          result_two: 'Second output artifact',
          result_three: 'Third output artifact'
        )
      end
    end

    it 'validates all output artifacts' do
      output_artifacts = { result_one: 'abc', result_two: 'def', result_three: 'ghi' }
      expect(output_agent_class.new(->(_) { output_artifacts }).run).to eq(output_artifacts)
    end

    it 'raises MissingOutputArtifactError when some output artifacts are missing' do
      # Returning only 1 out of 3 expected outputs
      agent = output_agent_class.new(->(_) { { result_one: 'abc' } })

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

  context 'with subclass defining output artifacts from parent classes as well' do
    let(:output_agent_class) do
      Class.new(
        Class.new(ComposableAgents::RubyAgent) do
          prepend ComposableAgents::Mixins::ArtifactContract

          output_artifacts(
            result_one: 'First output artifact',
            result_two: 'Second output artifact'
          )
        end
      ) do
        prepend ComposableAgents::Mixins::ArtifactContract

        output_artifacts(result_three: 'Third output artifact')
      end
    end

    it 'validates all output artifacts' do
      output_artifacts = { result_one: 'abc', result_two: 'def', result_three: 'ghi' }
      expect(output_agent_class.new(->(_) { output_artifacts }).run).to eq(output_artifacts)
    end

    it 'raises MissingOutputArtifactError when some output artifacts are missing' do
      # Returning only 1 out of 3 expected outputs
      agent = output_agent_class.new(->(_) { { result_one: 'abc' } })

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
