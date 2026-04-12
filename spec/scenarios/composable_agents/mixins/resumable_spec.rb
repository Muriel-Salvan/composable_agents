require 'tmpdir'
require 'composable_agents/mixins/resumable'
require 'composable_agents/agent'

describe ComposableAgents::Mixins::Resumable do
  context 'with a sequential workflow' do
    # Get a resumable agent
    #
    # @param run_id [String, NilClass] The run ID to give to this agent
    # @yield [agent] Yields the resumable agent
    # @yieldparam agent [Agent] The resumable agent
    def with_resumable_agent(run_id: nil)
      Dir.mktmpdir do |composable_agents_dir|
        yield(
          Class.new(ComposableAgents::Agent) do
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
        )
      end
    end

    context 'without any run ID' do
      it 'executes steps normally' do
        with_resumable_agent do |agent|
          expect(agent.run(input_artifacts: { input: 1 })).to eq(
            input: 1,
            step1_output: 2,
            step2_output: 3
          )
          expect(agent.executed_steps).to eq %i[step1 step2]
        end
      end

      it 'executes steps again' do
        with_resumable_agent do |agent|
          agent.run(input_artifacts: { input: 1 })
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
        with_resumable_agent(run_id:) do |agent|
          expect(agent.run(input_artifacts: { input: 1 })).to eq(
            input: 1,
            step1_output: 2,
            step2_output: 3
          )
          expect(agent.executed_steps).to eq %i[step1 step2]
        end
      end

      it 'does not execute same steps again' do
        with_resumable_agent(run_id:) do |agent|
          agent.run(input_artifacts: { input: 1 })
          agent.executed_steps = []
          expect(agent.run(input_artifacts: { input: 1 })).to eq(
            input: 1,
            step1_output: 2,
            step2_output: 3
          )
          expect(agent.executed_steps).to eq []
        end
      end

      it 'executes remaining steps after being interrupted' do
        with_resumable_agent(run_id:) do |agent|
          agent.skip_step2 = true
          agent.run(input_artifacts: { input: 1 })
          agent.executed_steps = []
          agent.skip_step2 = false
          expect(agent.run(input_artifacts: { input: 1 })).to eq(
            input: 1,
            step1_output: 2,
            step2_output: 3
          )
          expect(agent.executed_steps).to eq %i[step2]
        end
      end

      it 're-executes steps for different input artifacts' do
        with_resumable_agent(run_id:) do |agent|
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
    end
  end

  context 'with a nested workflow' do
    # Get a resumable agent
    #
    # @param run_id [String, NilClass] The run ID to give to this agent
    # @yield [agent] Yields the resumable agent
    # @yieldparam agent [Agent] The resumable agent
    def with_resumable_agent(run_id: nil)
      Dir.mktmpdir do |composable_agents_dir|
        yield(
          Class.new(ComposableAgents::Agent) do
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
        )
      end
    end

    context 'without any run ID' do
      it 'executes steps normally' do
        with_resumable_agent do |agent|
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
    end

    context 'with a run ID' do
      let(:run_id) { 'test-run' }

      it 'executes steps normally' do
        with_resumable_agent(run_id:) do |agent|
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

      it 'executes remaining steps after being interrupted' do
        with_resumable_agent(run_id:) do |agent|
          agent.interrupt_step12 = true
          begin
            agent.run(input_artifacts: { input: 1 })
          rescue RuntimeError
            # We expect this exception
          end
          agent.executed_steps = []
          agent.interrupt_step12 = false
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
  end

  context 'with various artifacts types' do
    let(:run_id) { 'test-run' }

    # Get a resumable agent
    #
    # @param run_id [String, NilClass] The run ID to give to this agent
    # @yield [agent] Yields the resumable agent
    # @yieldparam agent [Agent] The resumable agent
    def with_resumable_agent(run_id: nil)
      Dir.mktmpdir do |composable_agents_dir|
        yield(
          Class.new(ComposableAgents::Agent) do
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
        )
      end
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
        with_resumable_agent(run_id:) do |agent|
          agent.skip_step2 = true
          agent.run(input_artifacts: { input: data })
          agent.executed_steps = []
          agent.skip_step2 = false
          expect(agent.run(input_artifacts: { input: data })).to eq(
            input: data,
            step1_output: data,
            step2_output: data
          )
          expect(agent.executed_steps).to eq %i[step2]
        end
      end
    end
  end
end
