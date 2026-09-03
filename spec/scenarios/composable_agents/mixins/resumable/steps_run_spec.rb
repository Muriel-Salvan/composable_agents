require 'tmpdir'

describe ComposableAgents::Mixins::Resumable, '#steps_run' do
  attr_reader :composable_agents_dir

  around do |example|
    Dir.mktmpdir do |dir|
      @composable_agents_dir = dir
      example.run
    end
  end

  let(:run_id) { nil }

  # Creates a simple child agent to be used with the step_agent method.
  #
  # @param name [String] Name of the child agent
  # @return [ComposableAgents::Agent] Child agent instance
  def child_agent(name: 'child')
    Class.new(ComposableAgents::Agent) do
      def run(**input_artifacts)
        { child_output: input_artifacts[:input] + 10 }
      end
    end.new(name:, composable_agents_dir:)
  end

  it 'returns an empty list when nothing has run' do
    agent = Class.new(ComposableAgents::Agent) do
      prepend ComposableAgents::Mixins::Resumable
    end.new
    expect(agent.steps_run).to eq []
  end

  it 'records a single simple step' do
    agent = Class.new(ComposableAgents::Agent) do
      prepend ComposableAgents::Mixins::Resumable

      def run
        step(:step1) do
          # Nothing to do
        end
        {}
      end
    end.new(composable_agents_dir:, run_id:)

    agent.run
    expect(agent.steps_run).to eq [
      [
        {
          step_name: :step1,
          agent: nil,
          extra_input_artifacts: {},
          children: [],
          status: :executed
        }
      ]
    ]
  end

  it 'records a single simple step with extra input artifacts' do
    agent = Class.new(ComposableAgents::Agent) do
      prepend ComposableAgents::Mixins::Resumable

      def run
        step(:step1, extra_artifact: 42) do
          # Nothing to do
        end
        @artifacts
      end
    end.new(composable_agents_dir:, run_id:)

    agent.run
    expect(agent.steps_run).to eq [
      [
        {
          step_name: :step1,
          agent: nil,
          extra_input_artifacts: { extra_artifact: 42 },
          children: [],
          status: :executed
        }
      ]
    ]
  end

  it 'records a single agent_step' do
    child = child_agent(name: 'child')
    agent = Class.new(ComposableAgents::Agent) do
      prepend ComposableAgents::Mixins::Resumable

      attr_accessor :child_agent

      def run
        @artifacts.merge!(input: 42)
        step_agent(child_agent)
        @artifacts
      end
    end.new(composable_agents_dir:, run_id:)
    agent.child_agent = child

    agent.run
    expect(agent.steps_run).to eq [
      [
        {
          step_name: :agent_run_child,
          agent: child,
          extra_input_artifacts: {},
          children: [],
          status: :executed
        }
      ]
    ]
  end

  it 'records a single agent_step with extra input artifacts' do
    child = child_agent(name: 'child')
    agent = Class.new(ComposableAgents::Agent) do
      prepend ComposableAgents::Mixins::Resumable

      attr_accessor :child_agent

      def run
        step_agent(child_agent, input: 42)
        @artifacts
      end
    end.new(composable_agents_dir:, run_id:)
    agent.child_agent = child

    agent.run
    expect(agent.steps_run).to eq [
      [
        {
          step_name: :agent_run_child,
          agent: child,
          extra_input_artifacts: { input: 42 },
          children: [],
          status: :executed
        }
      ]
    ]
  end

  it 'records several root steps' do
    agent = Class.new(ComposableAgents::Agent) do
      prepend ComposableAgents::Mixins::Resumable

      def run
        step(:step1) do
          # Nothing to do
        end
        step(:step2) do
          # Nothing to do
        end
        step(:step3) do
          # Nothing to do
        end
        {}
      end
    end.new(composable_agents_dir:, run_id:)

    agent.run
    expect(agent.steps_run).to eq [
      [
        {
          step_name: :step1,
          agent: nil,
          extra_input_artifacts: {},
          children: [],
          status: :executed
        },
        {
          step_name: :step2,
          agent: nil,
          extra_input_artifacts: {},
          children: [],
          status: :executed
        },
        {
          step_name: :step3,
          agent: nil,
          extra_input_artifacts: {},
          children: [],
          status: :executed
        }
      ]
    ]
  end

  it 'records nested steps' do
    agent = Class.new(ComposableAgents::Agent) do
      prepend ComposableAgents::Mixins::Resumable

      def run
        step(:step1) do
          # Nothing to do
          step(:step11) do
            # Nothing to do
          end
          step(:step12) do
            # Nothing to do
          end
        end
        step(:step2) do
          # Nothing to do
          step(:step21) do
            # Nothing to do
          end
        end
        {}
      end
    end.new(composable_agents_dir:, run_id:)

    agent.run
    expect(agent.steps_run).to eq [
      [
        {
          step_name: :step1,
          agent: nil,
          extra_input_artifacts: {},
          children: [
            {
              step_name: :step11,
              agent: nil,
              extra_input_artifacts: {},
              children: [],
              status: :executed
            },
            {
              step_name: :step12,
              agent: nil,
              extra_input_artifacts: {},
              children: [],
              status: :executed
            }
          ],
          status: :executed
        },
        {
          step_name: :step2,
          agent: nil,
          extra_input_artifacts: {},
          children: [
            {
              step_name: :step21,
              agent: nil,
              extra_input_artifacts: {},
              children: [],
              status: :executed
            }
          ],
          status: :executed
        }
      ]
    ]
  end

  it 'records nested steps using a mix of agent_step and step' do
    child1 = child_agent(name: 'child1')
    child2 = child_agent(name: 'child2')
    agent = Class.new(ComposableAgents::Agent) do
      prepend ComposableAgents::Mixins::Resumable

      attr_accessor :child1_agent
      attr_accessor :child2_agent

      def run
        step(:step1) do
          step_agent(child1_agent, input: 1)
          step(:step11) do
            # Nothing to do
          end
        end
        step_agent(child2_agent, input: 2)
        {}
      end
    end.new(composable_agents_dir:, run_id:)
    agent.child1_agent = child1
    agent.child2_agent = child2

    agent.run
    expect(agent.steps_run).to eq [
      [
        {
          step_name: :step1,
          agent: nil,
          extra_input_artifacts: {},
          children: [
            {
              step_name: :agent_run_child1,
              agent: child1,
              extra_input_artifacts: { input: 1 },
              children: [],
              status: :executed
            },
            {
              step_name: :step11,
              agent: nil,
              extra_input_artifacts: {},
              children: [],
              status: :executed
            }
          ],
          status: :executed
        },
        {
          step_name: :agent_run_child2,
          agent: child2,
          extra_input_artifacts: { input: 2 },
          children: [],
          status: :executed
        }
      ]
    ]
  end

  it 'keeps the recorded steps of each run' do
    agent = Class.new(ComposableAgents::Agent) do
      prepend ComposableAgents::Mixins::Resumable

      attr_accessor :skip_step2

      def run
        step(:step1) do
          # Nothing to do
        end
        unless skip_step2
          step(:step2) do
            # Nothing to do
          end
        end
        {}
      end
    end.new(composable_agents_dir:, run_id:)

    agent.run
    # Run again with a different workflow: steps_run should record each run's steps, in order
    agent.skip_step2 = true
    agent.run
    expect(agent.steps_run).to eq [
      [
        {
          step_name: :step1,
          agent: nil,
          extra_input_artifacts: {},
          children: [],
          status: :executed
        },
        {
          step_name: :step2,
          agent: nil,
          extra_input_artifacts: {},
          children: [],
          status: :executed
        }
      ],
      [
        {
          step_name: :step1,
          agent: nil,
          extra_input_artifacts: {},
          children: [],
          status: :executed
        }
      ]
    ]
  end

  it 'records steps as cached when they are skipped because of a previous execution' do
    agent = Class.new(ComposableAgents::Agent) do
      prepend ComposableAgents::Mixins::Resumable

      def run
        step(:step1) do
          # Nothing to do
        end
        step(:step2) do
          # Nothing to do
        end
        {}
      end
    end.new(composable_agents_dir:, run_id: 'test-run')

    agent.run
    agent.run
    expect(agent.steps_run).to eq [
      [
        {
          step_name: :step1,
          agent: nil,
          extra_input_artifacts: {},
          children: [],
          status: :executed
        },
        {
          step_name: :step2,
          agent: nil,
          extra_input_artifacts: {},
          children: [],
          status: :executed
        }
      ],
      [
        {
          step_name: :step1,
          agent: nil,
          extra_input_artifacts: {},
          children: [],
          status: :cached
        },
        {
          step_name: :step2,
          agent: nil,
          extra_input_artifacts: {},
          children: [],
          status: :cached
        }
      ]
    ]
  end

  it 'records cached and executed statuses when resuming an interrupted run' do
    agent = Class.new(ComposableAgents::Agent) do
      prepend ComposableAgents::Mixins::Resumable

      attr_accessor :interrupt_step12

      def run
        step(:step1) do
          step(:step11) do
            # Nothing to do
          end
          step(:step12) do
            raise 'Test interruption' if interrupt_step12
          end
        end
        {}
      end
    end.new(composable_agents_dir:, run_id: 'test-run')

    # First run: interrupted inside step12, so only step11 is persisted
    agent.interrupt_step12 = true
    expect { agent.run }.to raise_error(RuntimeError, 'Test interruption')
    # Second run: step11 is skipped because of the previous execution, step12 is executed
    agent.interrupt_step12 = false
    agent.run
    expect(agent.steps_run).to eq [
      [
        {
          step_name: :step1,
          agent: nil,
          extra_input_artifacts: {},
          children: [
            {
              step_name: :step11,
              agent: nil,
              extra_input_artifacts: {},
              children: [],
              status: :executed
            },
            {
              step_name: :step12,
              agent: nil,
              extra_input_artifacts: {},
              children: [],
              status: :started
            }
          ],
          status: :started
        }
      ],
      [
        {
          step_name: :step1,
          agent: nil,
          extra_input_artifacts: {},
          children: [
            {
              step_name: :step11,
              agent: nil,
              extra_input_artifacts: {},
              children: [],
              status: :cached
            },
            {
              step_name: :step12,
              agent: nil,
              extra_input_artifacts: {},
              children: [],
              status: :executed
            }
          ],
          status: :executed
        }
      ]
    ]
  end

  it 'records started statuses for current steps and executed statuses for previous ones when dumped in the middle of a run' do
    agent = Class.new(ComposableAgents::Agent) do
      prepend ComposableAgents::Mixins::Resumable

      attr_accessor :dumped_steps_run

      def run
        step(:step1) do
          step(:step11) do
            # Nothing to do
          end
        end
        step(:step2) do
          step(:step21) do
            # Nothing to do
          end
          step(:step22) do
            # Dump a snapshot of the current steps_run hierarchy in the middle of the run
            self.dumped_steps_run = Marshal.load(Marshal.dump(steps_run))
          end
        end
        {}
      end
    end.new(composable_agents_dir:, run_id:)

    agent.run
    expect(agent.dumped_steps_run).to eq [
      [
        {
          step_name: :step1,
          agent: nil,
          extra_input_artifacts: {},
          children: [
            {
              step_name: :step11,
              agent: nil,
              extra_input_artifacts: {},
              children: [],
              status: :executed
            }
          ],
          status: :executed
        },
        {
          step_name: :step2,
          agent: nil,
          extra_input_artifacts: {},
          children: [
            {
              step_name: :step21,
              agent: nil,
              extra_input_artifacts: {},
              children: [],
              status: :executed
            },
            {
              step_name: :step22,
              agent: nil,
              extra_input_artifacts: {},
              children: [],
              status: :started
            }
          ],
          status: :started
        }
      ]
    ]
  end
end
