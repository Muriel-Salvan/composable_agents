describe ComposableAgents::Mixins::Retriable do
  # Builds a {ComposableAgents::Mixins::Retriable::RetryPolicy} with the given
  # values (all optional).
  #
  # @param wait_secs [Integer, Float, nil] seconds to wait before retrying
  # @param modifier [Proc, nil] proc to call with the agent before retrying
  # @return [ComposableAgents::Mixins::Retriable::RetryPolicy]
  def policy(wait_secs: nil, modifier: nil)
    ComposableAgents::Mixins::Retriable::RetryPolicy.new(
      wait_secs: wait_secs,
      modifier: modifier
    )
  end

  # Builds a {ComposableAgents::Agent} subclass that prepends
  # {ComposableAgents::Mixins::Retriable} and instruments +run+ with
  # +run_count+ and +model+ attributes.
  #
  # Each instance starts with +run_count+ at 0 and +model+ at 'default',
  # and its +run+ method delegates to +super+ before returning
  # { output: input_artifacts[:input] }.
  #
  # @return [ComposableAgents::Agent] a retriable agent instance
  def retriable_agent
    Class.new(ComposableAgents::Agent) do
      prepend ComposableAgents::Mixins::Retriable

      attr_accessor :run_count
      attr_accessor :model

      def run(**input_artifacts)
        super
        @run_count ||= 0
        @run_count += 1
        @model ||= 'default'
        { output: input_artifacts[:input] }
      end
    end.new
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
      agent.retry_on(->(a) {})
      expect(agent.run(input: 1)).to eq(output: 1)
      expect(agent.run_count).to eq(1)
    end
  end

  context 'with a proc returning a retry policy' do
    it 'retries the agent and returns the final output artifacts' do
      agent = retriable_agent
      agent.retry_on(->(a) { a.run_count == 1 ? policy : nil })
      expect(agent.run(input: 1)).to eq(output: 1)
      expect(agent.run_count).to eq(2)
    end

    it 'waits the configured number of seconds before retrying' do
      agent = retriable_agent
      agent.retry_on(->(a) { a.run_count == 1 ? policy(wait_secs: 3) : nil })
      allow(agent).to receive(:sleep).and_return(nil)
      expect(agent.run(input: 1)).to eq(output: 1)
      expect(agent.run_count).to eq(2)
      expect(agent).to have_received(:sleep).with(3)
    end

    it 'treats nil wait_secs as 0' do
      agent = retriable_agent
      agent.retry_on(->(a) { a.run_count == 1 ? policy(wait_secs: nil) : nil })
      expect(agent.run(input: 1)).to eq(output: 1)
      expect(agent.run_count).to eq(2)
    end

    it 'does not sleep when wait_secs is 0' do
      agent = retriable_agent
      agent.retry_on(->(a) { a.run_count == 1 ? policy(wait_secs: 0) : nil })
      allow(agent).to receive(:sleep)
      expect(agent.run(input: 1)).to eq(output: 1)
      expect(agent.run_count).to eq(2)
      expect(agent).not_to have_received(:sleep)
    end
  end

  context 'with multiple registered procs' do
    it 'evaluates them in registration order' do
      evaluation_log = []
      agent = retriable_agent
      agent.retry_on(
        lambda do |a|
          evaluation_log << :first
          nil
        end
      )
      agent.retry_on(
        lambda do |a|
          evaluation_log << :second
          a.run_count < 2 ? policy : nil
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
        lambda do |a|
          evaluation_log << :first
          a.run_count == 1 ? policy : nil
        end
      )
      agent.retry_on(
        lambda do |a|
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
      agent.retry_on(->(a) { a.run_count < 3 ? policy : nil })
      expect(agent.run(input: 1)).to eq(output: 1)
      expect(agent.run_count).to eq(3)
    end

    it 'propagates exceptions raised by procs' do
      agent = retriable_agent
      agent.retry_on(->(_a) { raise 'boom' })
      expect do
        agent.run(input: 1)
      end.to raise_error('boom')
      expect(agent.run_count).to eq(1)
    end
  end

  context 'with with_retry_on' do
    it 'registers the proc for the duration of the block and unregisters it after' do
      agent = retriable_agent
      agent.with_retry_on(->(a) { a.run_count == 1 ? policy : nil }) do
        expect(agent.run(input: 1)).to eq(output: 1)
        expect(agent.run_count).to eq(2)
      end
      expect(agent.run(input: 1)).to eq(output: 1)
      expect(agent.run_count).to eq(3)
    end

    it 'keeps procs registered inside the block' do
      agent = retriable_agent
      agent.with_retry_on(->(a) {}) do
        agent.retry_on(->(a) { a.run_count == 1 ? policy : nil })
      end
      expect(agent.run(input: 1)).to eq(output: 1)
      expect(agent.run_count).to eq(2)
    end

    it 'unregisters the proc even if the block raises' do
      agent = retriable_agent
      expect do
        agent.with_retry_on(->(_a) { policy }) do
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
      expect(agent.retry_on(->(a) {})).to be(agent)
    end

    it 'keeps a registered proc across several runs' do
      agent = retriable_agent
      agent.retry_on(->(a) { a.run_count == 1 ? policy : nil })
      expect(agent.run(input: 1)).to eq(output: 1)
      expect(agent.run_count).to eq(2)
    end
  end
end
