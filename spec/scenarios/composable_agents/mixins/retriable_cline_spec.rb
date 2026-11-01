describe ComposableAgents::Mixins::RetriableCline do
  # Creates a retriable Cline agent class that prepends the Retriable and RetriableCline mixins.
  # RetriableCline is prepended first so it sits inside the Retriable retry loop: this is required
  # for its per-retry run behaviour (like overriding user instructions on interactive session errors)
  # to be applied on each retry.
  # This agent automatically retries on Cline errors with exponential backoff and jitter.
  #
  # @param behavior [Proc, nil] optional proc called with the agent instance
  #   at the start of each +run+, once +run_count+ has been incremented. It can
  #   be used to raise exceptions or perform any additional behaviour without
  #   redefining +run+.
  # @param **kwargs [Hash] Additional keyword arguments passed to the agent class
  # @return [Class] A new class including Retriable and RetriableCline mixins,
  #   descending from ComposableAgents::Cline::Agent
  def retriable_cline_agent(behavior = nil, **kwargs)
    new_agent = Class.new(ComposableAgents::Cline::Agent) do
      prepend ComposableAgents::Mixins::RetriableCline
      prepend ComposableAgents::Mixins::Retriable

      # @return [Proc, nil] Optional behavior called at the start of each #run
      attr_accessor :behavior

      # @return [Integer] The number of times #run has been called
      attr_accessor :run_count

      # @return [String, nil] The last instructions received by #converse
      attr_accessor :last_instructions

      # Run the agent, incrementing the run counter and calling the optional behavior
      # before delegating to the parents.
      #
      # The behavior proc receives the agent instance and can raise an exception to simulate
      # a non-Cline error raised from the agent's own run logic.
      #
      # @param user_instructions [String, nil] Instructions for the user prompt, or nil if none
      # @param **input_artifacts [Hash] Additional input artifacts content, per artifact name
      # @return [Object] The result of calling super (the parent run method)
      def run(user_instructions: nil, **input_artifacts)
        @run_count ||= 0
        @run_count += 1
        behavior&.call(self)
        super
      end

      # Converse with the agent, storing the instructions for later retrieval.
      #
      # @param instructions [String] The instructions to pass to the agent
      # @param input_artifacts [Hash] Additional input artifacts (default: {})
      # @param author [String] The author/origin of the instructions (default: 'Orchestrator')
      # @return [Object] The result of calling super (the parent run method)
      def converse(instructions, input_artifacts: {}, author: 'Orchestrator')
        @last_instructions = instructions
        super
      end
    end.new(strategy: ComposableAgentsTest::TestRenderingStrategy, **kwargs)
    new_agent.behavior = behavior
    new_agent
  end

  # Returns a hash representing a failing result with exit code 1 and an error log.
  #
  # @return [Hash] A hash with keys: +exit+ (1), +log+ (nested hash with level and err),
  #   and +session+ (hash with status 'failed')
  def failing_result
    { exit: 1, log: { level: 40, err: { message: 'boom' } }, session: { status: 'failed' } }
  end

  # Returns an array composed of +failures+ copies of +failing_result+ followed by a +success+ hash.
  #
  # @param failures [Integer] The number of failing results to include
  # @param success [Hash] A hash with +stdout+ and +exit+ keys representing success (default: {stdout: 'done', exit: 0})
  # @return [Array<Hash>] An array starting with +failures+ error results followed by one success result
  def failing_then_success(failures, success: { stdout: 'done', exit: 0 })
    Array.new(failures) { failing_result } + [success]
  end

  describe 'retry on ClineError' do
    it 'retries and succeeds' do
      agent = retriable_cline_agent(cline_errors_retry_jitter: 0)
      mock_cline_for(agent, failing_then_success(1))
      mock_sleeps(agent)
      agent.run
      expect(sleep_calls).to eq [5]
      expect(agent.spy[:user_prompts].size).to eq(2)
    end

    it 'uses exponential backoff' do
      agent = retriable_cline_agent(cline_errors_retry_jitter: 0)
      mock_cline_for(agent, failing_then_success(3))
      mock_sleeps(agent)
      agent.run
      expect(sleep_calls).to eq [5, 10, 20]
      expect(agent.spy[:user_prompts].size).to eq(4)
    end

    it 'caps the delay at the maximum' do
      agent = retriable_cline_agent(
        cline_errors_retry_initial_delay_secs: 100,
        cline_errors_retry_jitter: 0
      )
      mock_cline_for(agent, failing_then_success(3))
      mock_sleeps(agent)
      agent.run
      expect(sleep_calls).to eq [60, 60, 60]
    end

    it 'uses custom retry parameters' do
      agent = retriable_cline_agent(
        cline_errors_max_retries: 5,
        cline_errors_retry_initial_delay_secs: 1,
        cline_errors_retry_backoff_factor: 3,
        cline_errors_retry_max_delay_secs: 80,
        cline_errors_retry_jitter: 0
      )
      mock_cline_for(agent, failing_then_success(5))
      mock_sleeps(agent)
      agent.run
      expect(sleep_calls).to eq [1, 3, 9, 27, 80]
    end
  end

  describe 'max retries exceeded' do
    it 're-raises the original ClineError' do
      agent = retriable_cline_agent
      mock_cline_for(agent, Array.new(4) { failing_result })
      mock_sleeps(agent)
      expect { agent.run }.to raise_error(ComposableAgents::Cline::ClineError, /boom/)
      expect(agent.spy[:user_prompts].size).to eq(4)
    end

    it 're-raises after a custom max retries' do
      agent = retriable_cline_agent(cline_errors_max_retries: 2)
      mock_cline_for(agent, Array.new(3) { failing_result })
      mock_sleeps(agent)
      expect { agent.run }.to raise_error(ComposableAgents::Cline::ClineError, /boom/)
      expect(agent.spy[:user_prompts].size).to eq(3)
    end
  end

  describe 'non-cline exception' do
    it 'does not retry' do
      agent = retriable_cline_agent(->(_agent) { raise 'boom' })
      expect { agent.run }.to raise_error(RuntimeError, /boom/)
      expect(agent.run_count).to eq(1)
    end
  end

  describe 'UnexpectedInteractiveSessionError' do
    it 'retries with overridden user instructions' do
      call_count = 0
      agent = retriable_cline_agent(
        lambda do |_agent|
          call_count += 1
          raise Cline::Cli::UnexpectedInteractiveSessionError, 'interactive' if call_count == 1
        end,
        cline_errors_retry_jitter: 0
      )
      mock_cline_for(agent)
      mock_sleeps(agent)
      agent.run
      expect(sleep_calls).to eq [5]
      expect(agent.last_instructions)
        .to eq(
          <<~TEXT
            You are not running in interactive mode, so you will not receive any input from the user.
            If you were expecting to ask the user a question, you must find the best answer to your question by yourself
            and proceed without user input.
          TEXT
        )
    end
  end

  describe 'jitter' do
    it 'does not apply jitter when jitter is 0' do
      agent = retriable_cline_agent(cline_errors_retry_jitter: 0)
      mock_cline_for(agent, failing_then_success(1))
      mock_sleeps(agent)
      agent.run
      expect(sleep_calls).to eq [5]
    end

    it 'applies default jitter of 10% around the computed delay' do
      agent = retriable_cline_agent(cline_errors_retry_initial_delay_secs: 10)
      mock_cline_for(agent, failing_then_success(1))
      mock_sleeps(agent)
      allow(agent).to receive(:rand).and_return(0.0)
      agent.run
      expect(sleep_calls).to eq [9]
    end

    it 'adds default jitter of 10% to the computed delay' do
      agent = retriable_cline_agent(cline_errors_retry_initial_delay_secs: 10)
      mock_cline_for(agent, failing_then_success(1))
      mock_sleeps(agent)
      allow(agent).to receive(:rand).and_return(1.0)
      agent.run
      expect(sleep_calls).to eq([11])
    end
  end
end
