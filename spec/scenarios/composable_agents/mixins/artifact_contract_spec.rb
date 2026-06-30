describe ComposableAgents::Mixins::ArtifactContract do
  context 'with artifacts contracts taken from instance methods' do
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

      context 'with optional input artifacts' do
        let(:agent) do
          Class.new(ComposableAgents::Agent) do
            prepend ComposableAgents::Mixins::ArtifactContract

            attr_reader :received_artifacts

            def input_artifacts_contracts
              {
                required: 'Required input artifact',
                optional: { description: 'Optional input artifact', optional: true }
              }
            end

            def output_artifacts_contracts
              {}
            end

            def run(**input_artifacts)
              @received_artifacts = input_artifacts
            end
          end.new
        end

        it 'does not fail validation when optional artifacts are missing' do
          agent.run(required: 10)
          expect(agent.received_artifacts).to eq({ required: 10 })
        end

        it 'accepts optional artifacts when they are provided' do
          agent.run(required: 10, optional: 20)
          expect(agent.received_artifacts).to eq({ required: 10, optional: 20 })
        end
      end

      context 'with input artifacts type definitions' do
        let(:agent) do
          Class.new(ComposableAgents::Agent) do
            prepend ComposableAgents::Mixins::ArtifactContract

            attr_reader :received_artifacts

            def input_artifacts_contracts
              {
                text_field: { description: 'A text field', type: :text },
                markdown_field: { description: 'A markdown field', type: :markdown },
                json_field: { description: 'A JSON field', type: :json }
              }
            end

            def output_artifacts_contracts
              {}
            end

            def run(**input_artifacts)
              @received_artifacts = input_artifacts
            end
          end.new
        end

        it 'accepts valid text artifact' do
          agent.run(
            text_field: 'Hello world',
            markdown_field: '# Heading',
            json_field: { 'key' => 'value' }
          )
          expect(agent.received_artifacts).not_to be_nil
        end

        it 'raises ArtifactTypeError for invalid text artifact type (Integer)' do
          expect do
            agent.run(
              text_field: 123,
              markdown_field: '# Heading',
              json_field: { 'key' => 'value' }
            )
          end.to raise_error(
            ComposableAgents::Mixins::ArtifactContract::ArtifactTypeError,
            /Artifact text_field should be a text String but is actually a Integer/
          )
        end

        it 'raises ArtifactTypeError for invalid markdown artifact type' do
          expect do
            agent.run(
              text_field: 'Hello',
              markdown_field: :not_a_string,
              json_field: { 'key' => 'value' }
            )
          end.to raise_error(
            ComposableAgents::Mixins::ArtifactContract::ArtifactTypeError,
            /Artifact markdown_field should be a markdown String but is actually a Symbol/
          )
        end

        it 'raises ArtifactTypeError for invalid json artifact type' do
          expect do
            agent.run(
              text_field: 'Hello',
              markdown_field: '# Heading',
              json_field: :not_json
            )
          end.to raise_error(
            ComposableAgents::Mixins::ArtifactContract::ArtifactTypeError,
            /Artifact json_field should be a JSON object but serializing it into JSON changed its data/
          )
        end

        it 'raises ArtifactTypeError when JSON serialization fails' do
          expect do
            agent.run(
              text_field: 'Hello',
              markdown_field: '# Heading',
              json_field: BasicObject.new
            )
          end.to raise_error(
            ComposableAgents::Mixins::ArtifactContract::ArtifactTypeError,
            /Artifact json_field should be a JSON object but parsing it raised error: undefined method 'to_s' for an instance of BasicObject/
          )
        end

        it 'raises ArtifactTypeError for an unknown artifact type' do
          agent_unknown = Class.new(ComposableAgents::Agent) do
            prepend ComposableAgents::Mixins::ArtifactContract

            attr_reader :received_artifacts

            def input_artifacts_contracts
              {
                weird_field: { description: 'A weird field', type: :unknown }
              }
            end

            def output_artifacts_contracts
              {}
            end

            def run(**input_artifacts)
              @received_artifacts = input_artifacts
            end
          end.new
          expect { agent_unknown.run(weird_field: 'Hello') }.to raise_error(
            ComposableAgents::Mixins::ArtifactContract::ArtifactTypeError,
            /Unknown artifact type: unknown/
          )
        end
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

      context 'with optional output artifacts' do
        let(:agent) do
          Class.new(ComposableAgents::Agent) do
            prepend ComposableAgents::Mixins::ArtifactContract

            attr_accessor :mocked_output_artifacts

            def input_artifacts_contracts
              {}
            end

            def output_artifacts_contracts
              {
                required: 'Required output artifact',
                optional: { description: 'Optional output artifact', optional: true }
              }
            end

            def run(**_input_artifacts)
              mocked_output_artifacts
            end
          end.new
        end

        it 'does not fail validation when optional artifacts are missing' do
          agent.mocked_output_artifacts = { required: 'abc' }
          expect(agent.run).to eq({ required: 'abc' })
        end

        it 'accepts optional artifacts when they are produced' do
          agent.mocked_output_artifacts = { required: 'abc', optional: 'def' }
          expect(agent.run).to eq({ required: 'abc', optional: 'def' })
        end
      end
    end
  end

  context 'with artifacts contracts taken from the constructor' do
    # Create an agent configured with the given input and output artifacts contracts
    #
    # @param input_artifacts_contracts [Hash<Symbol, Object>] The input artifacts contracts
    # @param output_artifacts_contracts [Hash<Symbol, Object>] The output artifacts contracts
    def described_agent(input_artifacts_contracts: {}, output_artifacts_contracts: {})
      Class.new(ComposableAgents::Agent) do
        prepend ComposableAgents::Mixins::ArtifactContract

        attr_accessor :mocked_output_artifacts
        attr_reader :received_artifacts

        # Run the agent with a set of input artifacts and get the corresponding output artifacts.
        #
        # @param input_artifacts [Hash<Symbol,Object>] The input artifacts content
        # @return Hash<Symbol,Object> Output artifacts content
        def run(**input_artifacts)
          @received_artifacts = input_artifacts
          mocked_output_artifacts || {}
        end
      end.new(input_artifacts_contracts:, output_artifacts_contracts:)
    end

    context 'with input artifacts definitions' do
      let(:agent) do
        described_agent(
          input_artifacts_contracts: {
            first: 'First input artifact',
            second: 'Second input artifact',
            third: 'Third input artifact'
          }
        )
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

      context 'with optional input artifacts' do
        let(:agent) do
          described_agent(
            input_artifacts_contracts: {
              required: 'Required input artifact',
              optional: { description: 'Optional input artifact', optional: true }
            }
          )
        end

        it 'does not fail validation when optional artifacts are missing' do
          agent.run(required: 10)
          expect(agent.received_artifacts).to eq({ required: 10 })
        end

        it 'accepts optional artifacts when they are provided' do
          agent.run(required: 10, optional: 20)
          expect(agent.received_artifacts).to eq({ required: 10, optional: 20 })
        end
      end
    end

    context 'with output artifacts definitions' do
      let(:agent) do
        described_agent(
          output_artifacts_contracts: {
            result_one: 'First output artifact',
            result_two: 'Second output artifact',
            result_three: 'Third output artifact'
          }
        )
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

      context 'with optional output artifacts' do
        let(:agent) do
          described_agent(
            output_artifacts_contracts: {
              required: 'Required output artifact',
              optional: { description: 'Optional output artifact', optional: true }
            }
          )
        end

        it 'does not fail validation when optional artifacts are missing' do
          agent.mocked_output_artifacts = { required: 'abc' }
          expect(agent.run).to eq({ required: 'abc' })
        end

        it 'accepts optional artifacts when they are produced' do
          agent.mocked_output_artifacts = { required: 'abc', optional: 'def' }
          expect(agent.run).to eq({ required: 'abc', optional: 'def' })
        end
      end
    end
  end

  context 'with type checking on output artifacts' do
    let(:agent) do
      Class.new(ComposableAgents::Agent) do
        prepend ComposableAgents::Mixins::ArtifactContract

        attr_accessor :mocked_output_artifacts

        def input_artifacts_contracts
          {}
        end

        def output_artifacts_contracts
          {
            text_result: { description: 'A text result', type: :text },
            markdown_result: { description: 'A markdown result', type: :markdown },
            json_result: { description: 'A JSON result', type: :json }
          }
        end

        def run(**_input_artifacts)
          mocked_output_artifacts
        end
      end.new
    end

    it 'accepts valid output artifacts with matching types' do
      agent.mocked_output_artifacts = {
        text_result: 'Hello',
        markdown_result: '# Title',
        json_result: { 'data' => 1 }
      }
      expect(agent.run).to eq(text_result: 'Hello', markdown_result: '# Title', json_result: { 'data' => 1 })
    end

    it 'raises ArtifactTypeError for invalid text output artifact type (Integer)' do
      agent.mocked_output_artifacts = {
        text_result: 42,
        markdown_result: '# Title',
        json_result: { 'data' => 1 }
      }
      expect { agent.run }.to raise_error(
        ComposableAgents::Mixins::ArtifactContract::ArtifactTypeError,
        /Artifact text_result should be a text String but is actually a Integer/
      )
    end

    it 'raises ArtifactTypeError for invalid markdown output artifact type' do
      agent.mocked_output_artifacts = {
        text_result: 'Hello',
        markdown_result: true,
        json_result: { 'data' => 1 }
      }
      expect { agent.run }.to raise_error(
        ComposableAgents::Mixins::ArtifactContract::ArtifactTypeError,
        /Artifact markdown_result should be a markdown String but is actually a TrueClass/
      )
    end

    it 'raises ArtifactTypeError for invalid json output artifact type' do
      agent.mocked_output_artifacts = {
        text_result: 'Hello',
        markdown_result: '# Title',
        json_result: :not_json
      }
      expect { agent.run }.to raise_error(
        ComposableAgents::Mixins::ArtifactContract::ArtifactTypeError,
        /Artifact json_result should be a JSON object but serializing it into JSON changed its data/
      )
    end

    it 'raises ArtifactTypeError when JSON serialization fails' do
      agent.mocked_output_artifacts = {
        text_result: 'Hello',
        markdown_result: '# Title',
        json_result: BasicObject.new
      }
      expect { agent.run }.to raise_error(
        ComposableAgents::Mixins::ArtifactContract::ArtifactTypeError,
        /Artifact json_result should be a JSON object but parsing it raised error: undefined method 'to_s' for an instance of BasicObject/
      )
    end

    it 'raises ArtifactTypeError for unknown artifact type' do
      agent_unknown = Class.new(ComposableAgents::Agent) do
        prepend ComposableAgents::Mixins::ArtifactContract

        attr_accessor :mocked_output_artifacts

        def input_artifacts_contracts
          {}
        end

        def output_artifacts_contracts
          { weird_field: { description: 'Weird type', type: :unknown } }
        end

        def run(**_input_artifacts)
          mocked_output_artifacts
        end
      end.new
      agent_unknown.mocked_output_artifacts = { weird_field: 'something' }
      expect { agent_unknown.run }.to raise_error(
        ComposableAgents::Mixins::ArtifactContract::ArtifactTypeError,
        /Unknown artifact type: unknown/
      )
    end
  end
end
