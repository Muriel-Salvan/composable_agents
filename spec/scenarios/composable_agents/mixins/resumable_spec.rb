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

        def run(input_artifacts: {})
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
        expect(agent.run(input_artifacts: { input: 1 })).to eq(
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
          expect(agent.run(input_artifacts: { input: 1 })).to eq(
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
        expect(agent.run(input_artifacts: { input: 1 })).to eq(
          input: 1,
          step1_output: 2,
          step2_output: 3
        )
        expect(agent.executed_steps).to eq %i[step1 step2]
      end

      it 'does not execute same steps again' do
        resumable_agent.run(input_artifacts: { input: 1 })
        agent = resumable_agent
        expect(agent.run(input_artifacts: { input: 1 })).to eq(
          input: 1,
          step1_output: 2,
          step2_output: 3
        )
        expect(agent.executed_steps).to eq []
      end

      it 'executes remaining steps after being interrupted' do
        resumable_agent(skip_step2: true).run(input_artifacts: { input: 1 })
        agent = resumable_agent
        expect(agent.run(input_artifacts: { input: 1 })).to eq(
          input: 1,
          step1_output: 2,
          step2_output: 3
        )
        expect(agent.executed_steps).to eq %i[step2]
      end

      it 're-executes steps for different input artifacts' do
        agent = resumable_agent
        agent.run(input_artifacts: { input: 1 })
        agent.executed_steps = []
        expect(agent.run(input_artifacts: { input: 2 })).to eq(
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
        resumable_agent.run(input_artifacts: { input: 1 })
        @run_id = 'test-run-2'
        agent = resumable_agent
        expect(agent.run(input_artifacts: { input: 1 })).to eq(
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

        def run(input_artifacts: {})
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
        expect(agent.run(input_artifacts: { input: 1 })).to eq(
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
        expect(agent.run(input_artifacts: { input: 1 })).to eq(
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
          resumable_agent(interrupt_step12: true).run(input_artifacts: { input: 1 })
        rescue RuntimeError
          # We expect this exception
        end
        agent = resumable_agent
        expect(agent.run(input_artifacts: { input: 1 })).to eq(
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

        def run(input_artifacts: {})
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
        resumable_agent(skip_step2: true).run(input_artifacts: { input: data })
        agent = resumable_agent
        expect(agent.run(input_artifacts: { input: data })).to eq(
          input: data,
          step1_output: data,
          step2_output: data
        )
        expect(agent.executed_steps).to eq %i[step2]
      end
    end
  end

  context 'with step_agent method' do
    # Creates a child agent for step_agent testing
    let(:child_agent) do
      Class.new(ComposableAgents::Agent) do
        attr_accessor :run_inputs

        def run(input_artifacts: {})
          @run_inputs ||= []
          @run_inputs << input_artifacts.dup
          {
            child_output: input_artifacts[:input] + 10,
            shared_value: input_artifacts[:shared_value] * 2
          }
        end
      end.new
    end

    # Creates a resumable agent instance with sequential workflow
    #
    # @param skip_step2 [Boolean] Should the agent skip step2?
    # @return [ComposableAgents::Agent] Resumable agent instance
    def resumable_agent(skip_step2: false)
      agent = Class.new(ComposableAgents::Agent) do
        prepend ComposableAgents::Mixins::Resumable

        attr_accessor :child_agent
        attr_accessor :skip_step2

        def run(input_artifacts: {})
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

    context 'without any run ID' do
      let(:run_id) { nil }

      it 'executes steps normally' do
        expect(resumable_agent.run(input_artifacts: { input: 1, shared_value: 1 })).to eq(
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
          expect(agent.run(input_artifacts: { input: 1, shared_value: 1 })).to eq(
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
        expect(resumable_agent.run(input_artifacts: { input: 1, shared_value: 1 })).to eq(
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
        resumable_agent.run(input_artifacts: { input: 1, shared_value: 1 })
        child_agent.run_inputs = []
        expect(resumable_agent.run(input_artifacts: { input: 1, shared_value: 1 })).to eq(
          input: 1,
          child_output: 11,
          shared_value: 4
        )
        expect(child_agent.run_inputs).to eq []
      end

      it 'executes remaining steps after being interrupted' do
        resumable_agent(skip_step2: true).run(input_artifacts: { input: 1, shared_value: 1 })
        child_agent.run_inputs = []
        expect(resumable_agent.run(input_artifacts: { input: 1, shared_value: 1 })).to eq(
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
        agent.run(input_artifacts: { input: 1, shared_value: 1 })
        expect(agent.run(input_artifacts: { input: 2, shared_value: 1 })).to eq(
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
        resumable_agent.run(input_artifacts: { input: 1, shared_value: 1 })
        @run_id = 'test-run-2'
        expect(resumable_agent.run(input_artifacts: { input: 1, shared_value: 1 })).to eq(
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
end
