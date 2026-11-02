describe ComposableAgents::Mixins::Retriable do
  # Builds a {ComposableAgents::Agent} subclass that prepends
  # {ComposableAgents::Mixins::Retriable} and instruments +run+ with
  # +run_count+, +model+, +state+ and +input_sequence+ attributes.
  #
  # Each instance starts with +run_count+ at 0 and +model+ at 'default',
  # and its +run+ method delegates to +super+ before returning
  # { output: input_artifacts[:input] }.
  #
  # @param behavior [Proc, nil] optional proc called with the agent instance
  #   at the end of each +run+, once +run_count+ has been incremented. It can
  #   be used to raise exceptions or perform any additional behaviour without
  #   redefining +run+.
  # @return [ComposableAgents::Agent] a retriable agent instance
  def retriable_agent(behavior = nil)
    new_agent = Class.new(ComposableAgents::Agent) do
      prepend ComposableAgents::Mixins::Retriable

      # @return [Proc, nil] Optional behaviour proc called with the agent
      #   instance at the end of each +run+, once +run_count+ has been
      #   incremented. It can be used to raise exceptions or perform any
      #   additional behaviour without redefining +run+.
      attr_accessor :behavior

      # @return [Integer] Number of completed runs (starts at 0)
      attr_accessor :run_count

      # @return [String] Model name, defaults to 'default'
      attr_accessor :model

      # @return [Hash] Mutable state map that can be set by retry policy
      #   +modifier+ procs registered via #retry_on.
      attr_accessor :state

      # @return [Array<Hash{Symbol => Object}>] Input artifacts passed to each
      #   invocation of #run, in chronological order.
      attr_accessor :input_sequence

      # @param input_artifacts [Hash{Symbol => Object}] Input artifacts
      # @return [Hash{Symbol => Object}] Output artifacts
      def run(**input_artifacts)
        super
        @run_count ||= 0
        @run_count += 1
        @model ||= 'default'
        @input_sequence ||= []
        @input_sequence << input_artifacts.dup
        behavior&.call(self)
        { output: input_artifacts[:input] }
      end
    end.new
    new_agent.behavior = behavior
    new_agent
  end

  context 'with no retry policy registered' do
    it 'runs once and returns the output artifacts' do
      agent = retriable_agent
      expect(agent.run(input: 1)).to eq(output: 1)
      expect(agent.run_count).to eq(1)
    end
  end

  context 'with a proc returning nil' do
    it 'runs once and returns the output artifacts' do
      agent = retriable_agent
      agent.retry_on(->(a, _exception) {})
      expect(agent.run(input: 1)).to eq(output: 1)
      expect(agent.run_count).to eq(1)
    end
  end

  context 'with a proc returning a retry policy' do
    it 'retries the agent and returns the final output artifacts' do
      agent = retriable_agent
      agent.retry_on(->(a, _exception) { a.run_count == 1 ? {} : nil })
      expect(agent.run(input: 1)).to eq(output: 1)
      expect(agent.run_count).to eq(2)
    end

    it 'waits the configured number of seconds before retrying' do
      agent = retriable_agent
      agent.retry_on(->(a, _exception) { a.run_count == 1 ? { wait_secs: 3 } : nil })
      allow(agent).to receive(:sleep).and_return(nil)
      expect(agent.run(input: 1)).to eq(output: 1)
      expect(agent.run_count).to eq(2)
      expect(agent).to have_received(:sleep).with(3)
    end

    it 'treats nil wait_secs as 0' do
      agent = retriable_agent
      agent.retry_on(->(a, _exception) { a.run_count == 1 ? { wait_secs: nil } : nil })
      expect(agent.run(input: 1)).to eq(output: 1)
      expect(agent.run_count).to eq(2)
    end

    it 'does not sleep when wait_secs is 0' do
      agent = retriable_agent
      agent.retry_on(->(a, _exception) { a.run_count == 1 ? { wait_secs: 0 } : nil })
      allow(agent).to receive(:sleep)
      expect(agent.run(input: 1)).to eq(output: 1)
      expect(agent.run_count).to eq(2)
      expect(agent).not_to have_received(:sleep)
    end
  end

  context 'with retry_on policies that modify input artifacts on retry' do
    it 'adds a new input artifact on the retry' do
      agent = retriable_agent
      agent.retry_on(->(a, _exception) { a.run_count == 1 ? { new_input_artifacts: { extra: 'hello' } } : nil })
      agent.run
      expect(agent.input_sequence).to eq([{}, { extra: 'hello' }])
    end

    it 'adds a new input artifact while keeping the original artifacts' do
      agent = retriable_agent
      agent.retry_on(->(a, _exception) { a.run_count == 1 ? { new_input_artifacts: { extra: 'hello' } } : nil })
      agent.run(input: 1)
      expect(agent.input_sequence).to eq([{ input: 1 }, { input: 1, extra: 'hello' }])
    end

    it 'replaces an existing input artifact on the retry' do
      agent = retriable_agent
      agent.retry_on(->(a, _exception) { a.run_count == 1 ? { new_input_artifacts: { input: 2 } } : nil })
      expect(agent.run(input: 1)).to eq(output: 2)
      expect(agent.input_sequence).to eq([{ input: 1 }, { input: 2 }])
    end

    it 'replaces an input artifact while keeping other artifacts' do
      agent = retriable_agent
      agent.retry_on(->(a, _exception) { a.run_count == 1 ? { new_input_artifacts: { input: 3, other: 'x' } } : nil })
      agent.run(input: 1)
      expect(agent.input_sequence).to eq([{ input: 1 }, { input: 3, other: 'x' }])
    end

    it 'deletes an existing input artifact on the retry' do
      agent = retriable_agent
      agent.retry_on(->(a, _exception) { a.run_count == 1 ? { new_input_artifacts: { input: nil } } : nil })
      expect(agent.run(input: 1)).to eq(output: nil)
      expect(agent.input_sequence).to eq([{ input: 1 }, { input: nil }])
    end

    it 'defaults new_input_artifacts to {} when omitted' do
      agent = retriable_agent
      agent.retry_on(->(a, _exception) { a.run_count == 1 ? { wait_secs: 0 } : nil })
      agent.run(input: 1)
      expect(agent.input_sequence).to eq([{ input: 1 }, { input: 1 }])
    end

    it 'applies the new input artifacts on a retry after an exception' do
      agent = retriable_agent(->(a) { raise 'boom' if a.run_count == 1 })
      agent.retry_on(->(a, _exception) { a.run_count == 1 ? { new_input_artifacts: { retry: true } } : nil })
      expect(agent.run(input: 1)).to eq(output: 1)
      expect(agent.input_sequence).to eq([{ input: 1 }, { input: 1, retry: true }])
    end

    it 'does not mutate the caller\'s original input artifacts' do
      original_input = { input: 1 }
      agent = retriable_agent
      agent.retry_on(->(a, _exception) { a.run_count == 1 ? { new_input_artifacts: { retry: true } } : nil })
      agent.run(**original_input)
      expect(agent.input_sequence).to eq([{ input: 1 }, { input: 1, retry: true }])
      expect(original_input).to eq(input: 1)
    end
  end

  context 'with retry_on policies that modify the agent state on retry' do
    it 'defaults the modifier to doing nothing when omitted' do
      agent = retriable_agent
      agent.retry_on(->(a, _exception) { a.run_count == 1 ? { wait_secs: 0 } : nil })
      agent.run(input: 1)
      expect(agent.state).to be_nil
    end

    it 'defaults the modifier to doing nothing when nil' do
      agent = retriable_agent
      agent.retry_on(->(a, _exception) { a.run_count == 1 ? { wait_secs: 0, modifier: nil } : nil })
      agent.run(input: 1)
      expect(agent.state).to be_nil
    end

    it 'calls the modifier with the agent before retrying' do
      agent = retriable_agent
      agent.retry_on(->(a, _exception) { a.run_count == 1 ? { modifier: ->(agent) { agent.state = :modified_by_retry_policy } } : nil })
      agent.run(input: 1)
      expect(agent.state).to eq(:modified_by_retry_policy)
    end

    it 'applies the modifier on a retry after an exception' do
      agent = retriable_agent(->(a) { raise 'boom' if a.run_count == 1 })
      agent.retry_on(
        proc do |a|
          if a.run_count == 1
            {
              wait_secs: 0,
              modifier: ->(agent) { agent.state = :exception }
            }
          end
        end
      )
      expect(agent.run(input: 1)).to eq(output: 1)
      expect(agent.state).to eq(:exception)
    end
  end

  context 'with multiple registered procs' do
    it 'evaluates them in registration order' do
      evaluation_log = []
      agent = retriable_agent
      agent.retry_on(
        proc do
          evaluation_log << :first
          nil
        end
      )
      agent.retry_on(
        proc do |a|
          evaluation_log << :second
          a.run_count < 2 ? {} : nil
        end
      )
      expect(agent.run(input: 1)).to eq(output: 1)
      expect(agent.run_count).to eq(2)
      expect(evaluation_log).to eq(%i[first second first second])
    end

    it 'stops evaluating further procs once one decides to retry' do
      evaluation_log = []
      agent = retriable_agent
      agent.retry_on(
        proc do |a|
          evaluation_log << :first
          a.run_count == 1 ? {} : nil
        end
      )
      agent.retry_on(
        proc do
          evaluation_log << :second
          nil
        end
      )
      expect(agent.run(input: 1)).to eq(output: 1)
      expect(agent.run_count).to eq(2)
      expect(evaluation_log).to eq(%i[first first second])
    end

    it 'supports multiple consecutive retries' do
      agent = retriable_agent
      agent.retry_on(->(a, _exception) { a.run_count < 3 ? {} : nil })
      expect(agent.run(input: 1)).to eq(output: 1)
      expect(agent.run_count).to eq(3)
    end

    it 'propagates exceptions raised by procs' do
      agent = retriable_agent
      agent.retry_on(->(_a, _exception) { raise 'boom' })
      expect do
        agent.run(input: 1)
      end.to raise_error('boom')
      expect(agent.run_count).to eq(1)
    end
  end

  context 'with with_retry_on' do
    it 'registers the proc for the duration of the block and unregisters it after' do
      agent = retriable_agent
      agent.with_retry_on(->(a, _exception) { a.run_count == 1 ? {} : nil }) do
        expect(agent.run(input: 1)).to eq(output: 1)
        expect(agent.run_count).to eq(2)
      end
      expect(agent.run(input: 1)).to eq(output: 1)
      expect(agent.run_count).to eq(3)
    end

    it 'keeps procs registered inside the block' do
      agent = retriable_agent
      agent.with_retry_on(->(a, _exception) {}) do
        agent.retry_on(->(a, _exception) { a.run_count == 1 ? {} : nil })
      end
      expect(agent.run(input: 1)).to eq(output: 1)
      expect(agent.run_count).to eq(2)
    end

    it 'unregisters the proc even if the block raises' do
      agent = retriable_agent
      expect do
        agent.with_retry_on(->(_a, _exception) { {} }) do
          raise 'boom'
        end
      end.to raise_error('boom')
      expect(agent.run(input: 1)).to eq(output: 1)
      expect(agent.run_count).to eq(1)
    end
  end

  context 'with retry_on' do
    it 'returns self so procs can be chained' do
      agent = retriable_agent
      expect(agent.retry_on(->(a, _exception) {})).to be(agent)
    end

    it 'keeps a registered proc across several runs' do
      agent = retriable_agent
      agent.retry_on(->(a, _exception) { a.run_count == 1 ? {} : nil })
      expect(agent.run(input: 1)).to eq(output: 1)
      expect(agent.run_count).to eq(2)
    end
  end

  context 'with exceptions raised by run' do
    it 'passes the exception to the procs as the second argument' do
      received_exception = nil
      agent = retriable_agent(->(_a) { raise 'run_failed' })
      agent.retry_on(lambda do |_a, exception|
        received_exception = exception
        nil
      end)
      expect do
        agent.run(input: 1)
      end.to raise_error('run_failed')
      expect(received_exception).to be_a(RuntimeError)
      expect(received_exception.message).to eq('run_failed')
    end

    it 'propagates the exception when no policy returns a retry policy' do
      agent = retriable_agent(->(_a) { raise 'run_failed' })
      agent.retry_on(->(_a, _exception) {})
      expect do
        agent.run(input: 1)
      end.to raise_error('run_failed')
      expect(agent.run_count).to eq(1)
    end

    it 'does not raise and applies the retry policy when one is returned' do
      agent = retriable_agent(->(a) { raise 'run_failed' if a.run_count == 1 })
      agent.retry_on(->(a, _exception) { a.run_count == 1 ? {} : nil })
      expect(agent.run(input: 1)).to eq(output: 1)
      expect(agent.run_count).to eq(2)
    end

    it 'propagates an exception raised on a retry attempt' do
      agent = retriable_agent(->(a) { raise 'retry_failed' if a.run_count == 2 })
      agent.retry_on(->(a, _exception) { a.run_count == 1 ? {} : nil })
      expect do
        agent.run(input: 1)
      end.to raise_error('retry_failed')
      expect(agent.run_count).to eq(2)
    end

    it 'retries after multiple exceptions and eventually succeeds' do
      agent = retriable_agent(->(a) { raise 'transient_error' if a.run_count < 3 })
      agent.retry_on(->(a, _exception) { a.run_count < 3 ? {} : nil })
      expect(agent.run(input: 1)).to eq(output: 1)
      expect(agent.run_count).to eq(3)
    end

    it 'waits the configured number of seconds when retrying after an exception' do
      agent = retriable_agent(->(a) { raise 'run_failed' if a.run_count == 1 })
      agent.retry_on(->(a, _exception) { a.run_count == 1 ? { wait_secs: 3 } : nil })
      allow(agent).to receive(:sleep).and_return(nil)
      expect(agent.run(input: 1)).to eq(output: 1)
      expect(agent.run_count).to eq(2)
      expect(agent).to have_received(:sleep).with(3)
    end
  end
end
