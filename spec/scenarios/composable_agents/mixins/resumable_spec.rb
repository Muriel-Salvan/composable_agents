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

            def run(input_artifacts: {})
              @executed_steps ||= []
              step(:step1) do
                @artifacts[:step1_output] = input_artifacts[:input] + 1
                @executed_steps << :step1
              end
              step(:step2) do
                @artifacts[:step2_output] = @artifacts[:step1_output] + 1
                @executed_steps << :step2
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
    end
  end
end
