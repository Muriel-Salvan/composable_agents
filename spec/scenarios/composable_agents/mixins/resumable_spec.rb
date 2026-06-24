require 'tmpdir'

describe ComposableAgents::Mixins::Resumable do
  attr_reader :composable_agents_dir

  around do |example|
    Dir.mktmpdir do |dir|
      @composable_agents_dir = dir
      example.run
    end
  end

  context 'with a sequential workflow' do
    # Creates a resumable agent instance with sequential workflow
    #
    # @param skip_step2 [Boolean] Should the agent skip step2?
    # @return [ComposableAgents::Agent] Resumable agent instance
    def resumable_agent(skip_step2: false)
      agent = Class.new(ComposableAgents::Agent) do
        prepend ComposableAgents::Mixins::Resumable

        attr_accessor :executed_steps
        attr_accessor :skip_step2

        def run(**input_artifacts)
          @executed_steps ||= []
          step(:step1) do
            @artifacts[:step1_output] = input_artifacts[:input] + 1
            executed_steps << :step1
          end
          unless skip_step2
            step(:step2) do
              @artifacts[:step2_output] = @artifacts[:step1_output] + 1
              executed_steps << :step2
            end
          end
          @artifacts
        end
      end.new(composable_agents_dir:, run_id:)
      agent.skip_step2 = skip_step2
      agent
    end

    context 'without any run ID' do
      let(:run_id) { nil }

      it 'executes steps normally' do
        agent = resumable_agent
        expect(agent.run(input: 1)).to eq(
          input: 1,
          step1_output: 2,
          step2_output: 3
        )
        expect(agent.executed_steps).to eq %i[step1 step2]
      end

      it 'executes steps again' do
        agent = resumable_agent
        2.times do
          agent.executed_steps = []
          expect(agent.run(input: 1)).to eq(
            input: 1,
            step1_output: 2,
            step2_output: 3
          )
          expect(agent.executed_steps).to eq %i[step1 step2]
        end
      end
    end

    context 'with a run ID' do
      let(:run_id) { 'test-run' }

      it 'executes steps normally' do
        agent = resumable_agent
        expect(agent.run(input: 1)).to eq(
          input: 1,
          step1_output: 2,
          step2_output: 3
        )
        expect(agent.executed_steps).to eq %i[step1 step2]
      end

      it 'does not execute same steps again' do
        resumable_agent.run(input: 1)
        agent = resumable_agent
        expect(agent.run(input: 1)).to eq(
          input: 1,
          step1_output: 2,
          step2_output: 3
        )
        expect(agent.executed_steps).to eq []
      end

      it 'executes remaining steps after being interrupted' do
        resumable_agent(skip_step2: true).run(input: 1)
        agent = resumable_agent
        expect(agent.run(input: 1)).to eq(
          input: 1,
          step1_output: 2,
          step2_output: 3
        )
        expect(agent.executed_steps).to eq %i[step2]
      end

      it 're-executes steps for different input artifacts' do
        agent = resumable_agent
        agent.run(input: 1)
        agent.executed_steps = []
        expect(agent.run(input: 2)).to eq(
          input: 2,
          step1_output: 3,
          step2_output: 4
        )
        expect(agent.executed_steps).to eq %i[step1 step2]
      end
    end

    context 'with different run ID' do
      attr_accessor :run_id

      it 're-executes steps for different run ID' do
        @run_id = 'test-run-1'
        resumable_agent.run(input: 1)
        @run_id = 'test-run-2'
        agent = resumable_agent
        expect(agent.run(input: 1)).to eq(
          input: 1,
          step1_output: 2,
          step2_output: 3
        )
        expect(agent.executed_steps).to eq %i[step1 step2]
      end
    end
  end

  context 'with a nested workflow' do
    # Creates a resumable agent instance with nested workflow
    #
    # @param interrupt_step12 [Boolean] Should the agent skip step2?
    # @return [ComposableAgents::Agent] Resumable agent instance
    def resumable_agent(interrupt_step12: false)
      agent = Class.new(ComposableAgents::Agent) do
        prepend ComposableAgents::Mixins::Resumable

        attr_accessor :executed_steps
        attr_accessor :interrupt_step12

        def run(**input_artifacts)
          @executed_steps ||= []
          step(:step1) do
            @artifacts[:step1_output] = input_artifacts[:input] + 1
            step(:step11) do
              @artifacts[:step11_output] = @artifacts[:step1_output] + 1
              executed_steps << :step11
            end
            step(:step12) do
              raise 'Test interruption of step12' if interrupt_step12

              @artifacts[:step12_output] = @artifacts[:step11_output] + 1
              executed_steps << :step12
            end
            executed_steps << :step1
          end
          step(:step2) do
            @artifacts[:step2_output] = @artifacts[:step12_output] + 1
            step(:step21) do
              @artifacts[:step21_output] = @artifacts[:step2_output] + 1
              step(:step211) do
                @artifacts[:step211_output] = @artifacts[:step21_output] + 1
                executed_steps << :step211
              end
              executed_steps << :step21
            end
            executed_steps << :step2
          end
          @artifacts
        end
      end.new(composable_agents_dir:, run_id:)
      agent.interrupt_step12 = interrupt_step12
      agent
    end

    context 'without any run ID' do
      let(:run_id) { nil }

      it 'executes steps normally' do
        agent = resumable_agent
        expect(agent.run(input: 1)).to eq(
          input: 1,
          step1_output: 2,
          step11_output: 3,
          step12_output: 4,
          step2_output: 5,
          step21_output: 6,
          step211_output: 7
        )
        expect(agent.executed_steps).to eq %i[step11 step12 step1 step211 step21 step2]
      end
    end

    context 'with a run ID' do
      let(:run_id) { 'test-run' }

      it 'executes steps normally' do
        agent = resumable_agent
        expect(agent.run(input: 1)).to eq(
          input: 1,
          step1_output: 2,
          step11_output: 3,
          step12_output: 4,
          step2_output: 5,
          step21_output: 6,
          step211_output: 7
        )
        expect(agent.executed_steps).to eq %i[step11 step12 step1 step211 step21 step2]
      end

      it 'executes remaining steps after being interrupted' do
        begin
          resumable_agent(interrupt_step12: true).run(input: 1)
        rescue RuntimeError
          # We expect this exception
        end
        agent = resumable_agent
        expect(agent.run(input: 1)).to eq(
          input: 1,
          step1_output: 2,
          step11_output: 3,
          step12_output: 4,
          step2_output: 5,
          step21_output: 6,
          step211_output: 7
        )
        expect(agent.executed_steps).to eq %i[step12 step1 step211 step21 step2]
      end
    end
  end

  context 'with various artifacts types' do
    let(:run_id) { 'test-run' }

    # Creates a resumable agent instance for testing different artifact types
    #
    # @param skip_step2 [Boolean] Should the agent skip step2?
    # @return [ComposableAgents::Agent] Resumable agent instance
    def resumable_agent(skip_step2: false)
      agent = Class.new(ComposableAgents::Agent) do
        prepend ComposableAgents::Mixins::Resumable

        attr_accessor :executed_steps
        attr_accessor :skip_step2

        def run(**input_artifacts)
          @executed_steps ||= []
          step(:step1) do
            @artifacts[:step1_output] = input_artifacts[:input]
            executed_steps << :step1
          end
          unless skip_step2
            step(:step2) do
              @artifacts[:step2_output] = @artifacts[:step1_output]
              executed_steps << :step2
            end
          end
          @artifacts
        end
      end.new(composable_agents_dir:, run_id:)
      agent.skip_step2 = skip_step2
      agent
    end

    {
      string: 'Test string',
      integer: 42,
      float: 11.07,
      array: [0.1, 0.2, 0.3],
      hash: {
        'first' => 0.1,
        'second' => 0.2,
        'third' => 0.3
      },
      nested: {
        'first' => [0.1, 'element', 42],
        'second' => {
          'a' => 1,
          'b' => 2,
          'c' => [
            3,
            4,
            {
              'd' => 5
            }
          ]
        }
      }
    }.each do |kind, data|
      it "resumes properly with artifacts of type #{kind}" do
        resumable_agent(skip_step2: true).run(input: data)
        agent = resumable_agent
        expect(agent.run(input: data)).to eq(
          input: data,
          step1_output: data,
          step2_output: data
        )
        expect(agent.executed_steps).to eq %i[step2]
      end
    end
  end

  context 'with step_agent method' do
    # Creates a resumable agent instance with sequential workflow
    #
    # @param skip_step2 [Boolean] Should the agent skip step2?
    # @return [ComposableAgents::Agent] Resumable agent instance
    def resumable_agent(skip_step2: false)
      agent = Class.new(ComposableAgents::Agent) do
        prepend ComposableAgents::Mixins::Resumable

        attr_accessor :child_agent
        attr_accessor :skip_step2

        def run(**input_artifacts)
          @artifacts.merge!(input_artifacts)
          step_agent(child_agent)
          step_agent(child_agent) unless skip_step2
          @artifacts
        end
      end.new(composable_agents_dir:, run_id:)
      agent.skip_step2 = skip_step2
      agent.child_agent = child_agent
      agent
    end

    context 'when using agents without states' do
      # Creates a child agent for step_agent testing
      let(:child_agent) do
        Class.new(ComposableAgents::Agent) do
          attr_accessor :run_inputs

          def run(**input_artifacts)
            @run_inputs ||= []
            @run_inputs << input_artifacts.dup
            {
              child_output: input_artifacts[:input] + 10,
              shared_value: input_artifacts[:shared_value] * 2
            }
          end
        end.new
      end

      context 'without any run ID' do
        let(:run_id) { nil }

        it 'executes steps normally' do
          expect(resumable_agent.run(input: 1, shared_value: 1)).to eq(
            input: 1,
            child_output: 11,
            shared_value: 4
          )
          expect(child_agent.run_inputs).to eq [
            { input: 1, shared_value: 1 },
            { input: 1, child_output: 11, shared_value: 2 }
          ]
        end

        it 'executes steps again' do
          agent = resumable_agent
          2.times do
            expect(agent.run(input: 1, shared_value: 1)).to eq(
              input: 1,
              child_output: 11,
              shared_value: 4
            )
          end
          expect(child_agent.run_inputs).to eq [
            { input: 1, shared_value: 1 },
            { input: 1, child_output: 11, shared_value: 2 },
            { input: 1, shared_value: 1 },
            { input: 1, child_output: 11, shared_value: 2 }
          ]
        end
      end

      context 'with a run ID' do
        let(:run_id) { 'test-run' }

        it 'executes steps normally' do
          expect(resumable_agent.run(input: 1, shared_value: 1)).to eq(
            input: 1,
            child_output: 11,
            shared_value: 4
          )
          expect(child_agent.run_inputs).to eq [
            { input: 1, shared_value: 1 },
            { input: 1, child_output: 11, shared_value: 2 }
          ]
        end

        it 'does not execute same steps again' do
          resumable_agent.run(input: 1, shared_value: 1)
          child_agent.run_inputs = []
          expect(resumable_agent.run(input: 1, shared_value: 1)).to eq(
            input: 1,
            child_output: 11,
            shared_value: 4
          )
          expect(child_agent.run_inputs).to eq []
        end

        it 'executes remaining steps after being interrupted' do
          resumable_agent(skip_step2: true).run(input: 1, shared_value: 1)
          child_agent.run_inputs = []
          expect(resumable_agent.run(input: 1, shared_value: 1)).to eq(
            input: 1,
            child_output: 11,
            shared_value: 4
          )
          expect(child_agent.run_inputs).to eq [
            { input: 1, child_output: 11, shared_value: 2 }
          ]
        end

        it 're-executes steps for different input artifacts' do
          agent = resumable_agent
          agent.run(input: 1, shared_value: 1)
          expect(agent.run(input: 2, shared_value: 1)).to eq(
            input: 2,
            child_output: 12,
            shared_value: 4
          )
          expect(child_agent.run_inputs).to eq [
            { input: 1, shared_value: 1 },
            { input: 1, child_output: 11, shared_value: 2 },
            { input: 2, shared_value: 1 },
            { input: 2, child_output: 12, shared_value: 2 }
          ]
        end
      end

      context 'with different run ID' do
        attr_accessor :run_id

        it 're-executes steps for different run ID' do
          @run_id = 'test-run-1'
          resumable_agent.run(input: 1, shared_value: 1)
          @run_id = 'test-run-2'
          expect(resumable_agent.run(input: 1, shared_value: 1)).to eq(
            input: 1,
            child_output: 11,
            shared_value: 4
          )
          expect(child_agent.run_inputs).to eq [
            { input: 1, shared_value: 1 },
            { input: 1, child_output: 11, shared_value: 2 },
            { input: 1, shared_value: 1 },
            { input: 1, child_output: 11, shared_value: 2 }
          ]
        end
      end
    end

    context 'when using agents with states' do
      # Creates a child agent for step_agent testing
      let(:child_agent) do
        Class.new(ComposableAgents::Agent) do
          attr_accessor :runs
          attr_accessor :state

          def initialize(*args, **kwargs)
            super
            @state = 0
          end

          def run(**input_artifacts)
            @runs ||= []
            @runs << {
              input: input_artifacts[:values],
              state: @state
            }
            @state += 1
            {
              values: input_artifacts[:values] + [@state]
            }
          end

          def export_state
            { 'state' => @state }
          end

          def import_state(state)
            @state = state['state']
          end
        end.new
      end

      context 'without any run ID' do
        let(:run_id) { nil }

        it 'executes steps normally' do
          expect(resumable_agent.run(values: [0])[:values]).to eq [0, 1, 2]
          expect(child_agent.runs).to eq [
            { input: [0], state: 0 },
            { input: [0, 1], state: 1 }
          ]
        end

        it 'executes steps again' do
          agent = resumable_agent
          expect(agent.run(values: [0])[:values]).to eq [0, 1, 2]
          expect(agent.run(values: [0])[:values]).to eq [0, 3, 4]
          expect(child_agent.runs).to eq [
            { input: [0], state: 0 },
            { input: [0, 1], state: 1 },
            { input: [0], state: 2 },
            { input: [0, 3], state: 3 }
          ]
        end
      end

      context 'with a run ID' do
        let(:run_id) { 'test-run' }

        it 'executes steps normally' do
          expect(resumable_agent.run(values: [0])[:values]).to eq [0, 1, 2]
          expect(child_agent.runs).to eq [
            { input: [0], state: 0 },
            { input: [0, 1], state: 1 }
          ]
        end

        it 'does not execute same steps again with a fresh state' do
          resumable_agent.run(values: [0])
          child_agent.state = 0
          child_agent.runs = []
          expect(resumable_agent.run(values: [0])[:values]).to eq [0, 1, 2]
          expect(child_agent.runs).to eq []
        end

        it 'executes steps again because of changing state' do
          resumable_agent.run(values: [0])
          child_agent.runs = []
          expect(resumable_agent.run(values: [0])[:values]).to eq [0, 3, 4]
          expect(child_agent.runs).to eq [
            { input: [0], state: 2 },
            { input: [0, 3], state: 3 }
          ]
        end

        it 'executes remaining steps after being interrupted' do
          resumable_agent(skip_step2: true).run(values: [0])
          child_agent.state = 0
          child_agent.runs = []
          expect(resumable_agent.run(values: [0])[:values]).to eq [0, 1, 2]
          expect(child_agent.runs).to eq [
            { input: [0, 1], state: 1 }
          ]
        end
      end

      context 'with different run ID' do
        attr_accessor :run_id

        it 're-executes steps for different run ID' do
          @run_id = 'test-run-1'
          resumable_agent.run(values: [0])
          @run_id = 'test-run-2'
          child_agent.state = 0
          expect(resumable_agent.run(values: [0])[:values]).to eq [0, 1, 2]
          expect(child_agent.runs).to eq [
            { input: [0], state: 0 },
            { input: [0, 1], state: 1 },
            { input: [0], state: 0 },
            { input: [0, 1], state: 1 }
          ]
        end
      end
    end

    context 'when using agents with mutable states' do
      let(:run_id) { 'test-run' }

      # Creates a child agent for step_agent testing
      def child_agent
        Class.new(ComposableAgents::Agent) do
          attr_accessor :runs
          attr_accessor :state

          def initialize(*args, **kwargs)
            super
            @state = { 'context' => { 'values' => [] } }
          end

          # Run the agent
          #
          # @param value [Integer] Input value
          def run(value:)
            @runs ||= []
            @runs << {
              input: value,
              state: @state
            }
            @state['context']['values'] << value
            {
              value: value + 1
            }
          end

          def export_state
            { 'state' => @state }
          end

          def import_state(state)
            @state = state['state']
          end
        end.new
      end

      it 'does not execute same steps again even with a child agent modifying a nested state' do
        resumable_agent.run(value: 0)
        agent2 = resumable_agent
        expect(agent2.run(value: 0)[:value]).to eq 2
        expect(agent2.child_agent.runs).to be_nil
      end
    end
  end

  context 'with additional input artifacts in step' do
    # Creates a resumable agent instance for testing extra input artifacts
    #
    # @return [ComposableAgents::Agent] Resumable agent instance
    def resumable_agent
      Class.new(ComposableAgents::Agent) do
        prepend ComposableAgents::Mixins::Resumable

        attr_accessor :executed_steps

        def run(**_input_artifacts)
          @executed_steps ||= []
          step(:step1, extra_artifact: 100) do
            @artifacts[:step1_output] = @artifacts[:input] + @artifacts[:extra_artifact]
            executed_steps << :step1
          end
          step(:step2, extra_artifact: 200) do
            @artifacts[:step2_output] = @artifacts[:step1_output] + @artifacts[:extra_artifact]
            executed_steps << :step2
          end
          @artifacts
        end
      end.new(composable_agents_dir:, run_id:)
    end

    context 'without any run ID' do
      let(:run_id) { nil }

      it 'executes steps normally with additional artifacts' do
        agent = resumable_agent
        expect(agent.run(input: 1)).to eq(
          input: 1,
          extra_artifact: 200,
          step1_output: 101,
          step2_output: 301
        )
        expect(agent.executed_steps).to eq %i[step1 step2]
      end
    end

    context 'with a run ID' do
      let(:run_id) { 'test-run' }

      it 'executes steps normally with additional artifacts' do
        agent = resumable_agent
        expect(agent.run(input: 1)).to eq(
          input: 1,
          extra_artifact: 200,
          step1_output: 101,
          step2_output: 301
        )
        expect(agent.executed_steps).to eq %i[step1 step2]
      end

      it 'does not execute same steps again when artifacts are the same' do
        resumable_agent.run(input: 1)
        agent = resumable_agent
        expect(agent.run(input: 1)).to eq(
          input: 1,
          extra_artifact: 200,
          step1_output: 101,
          step2_output: 301
        )
        expect(agent.executed_steps).to eq []
      end

      it 're-executes steps when extra artifacts differ' do
        first_agent = Class.new(ComposableAgents::Agent) do
          prepend ComposableAgents::Mixins::Resumable

          def run(**_input_artifacts)
            step(:step1, extra: 10) do
              @artifacts[:result] = @artifacts[:input] + @artifacts[:extra]
            end
            @artifacts
          end
        end.new(composable_agents_dir:, run_id:)

        second_agent = Class.new(ComposableAgents::Agent) do
          prepend ComposableAgents::Mixins::Resumable

          attr_accessor :executed_steps

          def run(**_input_artifacts)
            @executed_steps ||= []
            step(:step1, extra: 20) do
              @artifacts[:result] = @artifacts[:input] + @artifacts[:extra]
              executed_steps << :step1
            end
            @artifacts
          end
        end.new(composable_agents_dir:, run_id:)

        first_agent.run(input: 1)
        expect(second_agent.run(input: 1)).to eq(
          input: 1,
          extra: 20,
          result: 21
        )
        expect(second_agent.executed_steps).to eq %i[step1]
      end
    end
  end

  context 'with additional input artifacts in step_agent' do
    # Creates a resumable agent instance for testing extra input artifacts
    #
    # @return [ComposableAgents::Agent] Resumable agent instance
    def resumable_agent
      child = Class.new(ComposableAgents::Agent) do
        attr_accessor :runs_count

        def initialize(*)
          super
          @runs_count = 0
        end

        def run(**input_artifacts)
          @runs_count += 1
          {
            child_output: input_artifacts[:input] + 10
          }
        end
      end.new

      agent = Class.new(ComposableAgents::Agent) do
        prepend ComposableAgents::Mixins::Resumable

        attr_accessor :child_agent

        def run(**input_artifacts)
          @artifacts.merge!(input_artifacts)
          step_agent(child_agent, extra_param: 42)
          @artifacts
        end
      end.new(composable_agents_dir:, run_id:)
      agent.child_agent = child
      agent
    end

    context 'without any run ID' do
      let(:run_id) { nil }

      it 'executes step_agent normally with additional artifacts' do
        agent = resumable_agent
        expect(agent.run(input: 1)).to eq(
          input: 1,
          extra_param: 42,
          child_output: 11
        )
        expect(agent.child_agent.runs_count).to eq 1
      end
    end

    context 'with a run ID' do
      let(:run_id) { 'test-run' }

      it 'executes step_agent normally with additional artifacts' do
        agent = resumable_agent
        expect(agent.run(input: 1)).to eq(
          input: 1,
          extra_param: 42,
          child_output: 11
        )
        expect(agent.child_agent.runs_count).to eq 1
      end

      it 'does not execute same step_agent again when artifacts are the same' do
        resumable_agent.run(input: 1)
        agent = resumable_agent
        expect(agent.run(input: 1)).to eq(
          input: 1,
          extra_param: 42,
          child_output: 11
        )
        expect(agent.child_agent.runs_count).to eq 0
      end

      it 're-executes step_agent when extra artifacts differ' do
        child1 = Class.new(ComposableAgents::Agent) do
          attr_accessor :runs_count

          def initialize(*)
            super
            @runs_count = 0
          end

          def run(**input_artifacts)
            @runs_count += 1
            { child_output: input_artifacts[:input] + 10 }
          end
        end.new

        child2 = Class.new(ComposableAgents::Agent) do
          attr_accessor :runs_count

          def initialize(*)
            super
            @runs_count = 0
          end

          def run(**input_artifacts)
            @runs_count += 1
            { child_output: input_artifacts[:input] + 20 }
          end
        end.new

        first_agent = Class.new(ComposableAgents::Agent) do
          prepend ComposableAgents::Mixins::Resumable

          attr_accessor :child_agent

          def run(**input_artifacts)
            @artifacts.merge!(input_artifacts)
            step_agent(child_agent, extra_param: 10)
            @artifacts
          end
        end.new(composable_agents_dir:, run_id:)
        first_agent.child_agent = child1

        second_agent = Class.new(ComposableAgents::Agent) do
          prepend ComposableAgents::Mixins::Resumable

          attr_accessor :child_agent

          def run(**input_artifacts)
            @artifacts.merge!(input_artifacts)
            step_agent(child_agent, extra_param: 20)
            @artifacts
          end
        end.new(composable_agents_dir:, run_id:)
        second_agent.child_agent = child2

        first_agent.run(input: 1)
        expect(second_agent.run(input: 1)).to eq(
          input: 1,
          extra_param: 20,
          child_output: 21
        )
        expect(child2.runs_count).to eq 1
      end
    end
  end
end
