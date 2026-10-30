require 'spec_helper'

describe ComposableAgents::Mixins::RetriableArtifacts do
  # Build a {ComposableAgents::PromptDrivenAgent} subclass that prepends
  # {ComposableAgents::Mixins::RetriableArtifacts}, {ComposableAgents::Mixins::Retriable}
  # and {ComposableAgents::Mixins::ArtifactContract}, using the test rendering strategy.
  #
  # Each instance's +prompt+ method consumes the next entry from +mocked_outputs+,
  # saving any +output_artifacts+ and reporting any +output_artifacts_errors+ it
  # contains, and returns its +text+ (or an empty string when none is provided).
  # The +converse+ method records the rendered user prompt so it can be spied on.
  #
  # @param mocked_outputs [Array<Hash{Symbol => Object}>] List of mocked assistant
  #   outputs. Each entry may contain a +:text+ key (the assistant text), an
  #   +:output_artifacts+ key (a Hash of artifact name => content) and an
  #   +:output_artifacts_errors+ key (a Hash of artifact name => error message).
  # @param kwargs [Hash] Keyword args to be given to the agent's constructor
  # @return [ComposableAgents::PromptDrivenAgent] Agent to be tested
  def retriable_artifacts_agent(mocked_outputs = [], **kwargs)
    agent_class = Class.new(ComposableAgents::PromptDrivenAgent) do
      prepend ComposableAgents::Mixins::RetriableArtifacts
      prepend ComposableAgents::Mixins::Retriable
      prepend ComposableAgents::Mixins::ArtifactContract

      # @!attribute [RW] mocked_outputs
      #   List of mocked assistant outputs (see #retriable_artifacts_agent).
      attr_accessor :mocked_outputs

      # @!attribute [RW] output_artifacts
      #   The output artifacts accumulated during the run.
      attr_accessor :output_artifacts

      # @!attribute [RW] output_artifacts_errors
      #   The output artifacts errors encountered during the run.
      attr_accessor :output_artifacts_errors

      # Build a PromptDrivenAgent that prepends the RetriableArtifacts mixin.
      # Each invocation of +prompt+ consumes the next entry from +mocked_outputs+,
      # extracts any +:output_artifacts+, saves them via +save_output_artifact+,
      # reports any +:output_artifacts_errors+ via +report_error_for_output_artifact+,
      # and returns the +:text+ value (or an empty string when nil).
      #
      # @param _user_prompt [Object] The user prompt from the mocked output (typically
      #   a Hash with optional +:text+, +:output_artifacts+ and +:output_artifacts_errors+ keys).
      # @return [String] The text content of the prompt (or empty string when none).
      def prompt(_user_prompt)
        result = self.mocked_outputs.shift || raise('No more mocked outputs')
        output_artifacts = result.delete(:output_artifacts) || {}
        output_artifacts.each { |name, content| save_output_artifact(name, content) }
        output_artifacts_errors = result.delete(:output_artifacts_errors) || {}
        output_artifacts_errors.each { |name, error| report_error_for_output_artifact(name, error) }
        result[:text] || ''
      end

      # Build a PromptDrivenAgent that prepends the RetriableArtifacts mixin.
      # The +converse+ method renders user instructions, records the resulting user
      # prompt in +@user_prompts+, and delegates to +super+ (the parent +converse+)
      # from the PromptDrivenAgent mixin.
      #
      # @param instructions [String, Array<String>] Instructions for the user prompt.
      # @param input_artifacts [Hash{Symbol => Object}, nil] Optional input artifacts.
      # @param author [String] Author of this message. Usually 'Orchestrator'.
      # @return [void]
      def converse(instructions, input_artifacts: {}, author: 'Orchestrator')
        rendered_user_prompt = render_user_prompt(render_instructions(instructions), input_artifacts:)
        @user_prompts ||= []
        @user_prompts << rendered_user_prompt
        super
      end

      def spy
        { system_prompt: @system_prompt, user_prompts: @user_prompts || [] }
      end
    end
    new_agent = agent_class.new(strategy: ComposableAgentsTest::TestRenderingStrategy, **kwargs)
    new_agent.mocked_outputs = mocked_outputs.dup
    new_agent
  end

  describe '#run' do
    it 'does not retry when there are no expected output artifacts' do
      agent = retriable_artifacts_agent([{ text: 'Output' }], output_artifacts_contracts: {})
      agent.run
      expect(agent.spy[:user_prompts]).to eq ['USER_PROMPT[]']
    end

    it 'does not retry when all expected artifacts are returned on first run' do
      agent = retriable_artifacts_agent(
        [{ output_artifacts: { result: 'ok', logs: 'logs' } }],
        output_artifacts_contracts: { result: 'Final result', logs: 'Execution logs' }
      )
      expect(agent.run).to include(result: 'ok', logs: 'logs')
      expect(agent.spy[:user_prompts]).to eq ['USER_PROMPT[]']
    end

    it 'retries once when some artifacts are missing on first run' do
      agent = retriable_artifacts_agent(
        [
          { output_artifacts: { result: 'partial' } },
          { output_artifacts: { result: 'partial', logs: 'complete' } }
        ],
        output_artifacts_contracts: { result: 'Final result', logs: 'Execution logs' }
      )
      expect(agent.run).to include(result: 'partial', logs: 'complete')
      expect(agent.spy[:user_prompts].size).to eq(2)
      expect(agent.spy[:user_prompts][1]).to include('MISSING_PROMPT: logs (Execution logs)')
    end

    it 'retries multiple times until all artifacts are present' do
      agent = retriable_artifacts_agent(
        [
          {},
          { output_artifacts: { result: 'first' } },
          { output_artifacts: { result: 'second', logs: 'final' } }
        ],
        output_artifacts_contracts: { result: 'Final result', logs: 'Execution logs' }
      )
      expect(agent.run).to include(result: 'second', logs: 'final')
      expect(agent.spy[:user_prompts].size).to eq(3)
      expect(agent.spy[:user_prompts][1]).to include('MISSING_PROMPT: result (Final result), logs (Execution logs)')
      expect(agent.spy[:user_prompts][2]).to include('MISSING_PROMPT: logs (Execution logs)')
    end

    it 'completes missing output artifacts across sequential run calls' do
      agent = retriable_artifacts_agent(
        [
          { output_artifacts: { result: 'partial' } },
          { output_artifacts: { logs: 'complete' } },
          { output_artifacts: { result: 'partial', logs: 'complete' } }
        ],
        output_artifacts_contracts: { result: 'Final result', logs: 'Execution logs' }
      )
      # TODO: Wrong test case: can't be tested unless we have a max number of retries (so that first run fails, but second run completes).
      expect(agent.run).to include(result: 'partial', logs: 'complete')
      expect(agent.run(output_artifacts_contracts: { result: 'Final result', logs: 'Execution logs' })).to eq(result: 'partial', logs: 'complete')
      # TODO: Validate prompts
    end

    it 'subsequent runs can change output artifacts' do
      agent = retriable_artifacts_agent(
        [
          { output_artifacts: { result: 'first', logs: 'first_logs' } },
          { output_artifacts: { result: 'modified' } }
        ],
        output_artifacts_contracts: { result: 'Final result', logs: 'Execution logs' }
      )
      # First run produces both artifacts
      expect(agent.run).to include(result: 'first', logs: 'first_logs')
      # Second run produces only result (modified); logs persists from first run
      expect(agent.run).to include(result: 'modified', logs: 'first_logs')
    end

    it 'retries when run raises an OutputArtifactsError and asks for the artifact having errors' do
      agent = retriable_artifacts_agent(
        [
          { output_artifacts: { result: 'partial' }, output_artifacts_errors: { logs: 'Parsing error' } },
          { output_artifacts: { result: 'partial', logs: 'complete' } }
        ],
        output_artifacts_contracts: { result: 'Final result', logs: 'Execution logs' }
      )
      expect(agent.run).to include(result: 'partial', logs: 'complete')
      expect(agent.spy[:user_prompts].size).to eq(2)
      expect(agent.spy[:user_prompts][1]).to include('MISSING_PROMPT: logs (Execution logs) (Error: Parsing error)')
    end

    it 'asks for artifacts having errors with missing artifacts when run raises an OutputArtifactsError' do
      agent = retriable_artifacts_agent(
        [
          { output_artifacts_errors: { result: 'Parsing error' } },
          { output_artifacts: { result: 'ok', logs: 'complete' } }
        ],
        output_artifacts_contracts: { result: 'Final result', logs: 'Execution logs' }
      )
      expect(agent.run).to include(result: 'ok', logs: 'complete')
      expect(agent.spy[:user_prompts].size).to eq(2)
      expect(agent.spy[:user_prompts][1]).to include('MISSING_PROMPT: result (Final result) (Error: Parsing error), logs (Execution logs)')
    end

    it 'does not raise when output artifacts errors concern artifacts that are not expected outputs' do
      agent = retriable_artifacts_agent(
        [{ output_artifacts: { result: 'ok' }, output_artifacts_errors: { unknown: 'Parsing error' } }],
        output_artifacts_contracts: { result: 'Final result' }
      )
      expect(agent.run).to eq(result: 'ok')
      expect(agent.spy[:user_prompts].size).to eq(1)
    end

    it 'retries asking only for expected outputs when output artifacts errors concern expected and unexpected outputs' do
      agent = retriable_artifacts_agent(
        [
          { output_artifacts: { result: 'ok' }, output_artifacts_errors: { logs: 'Parsing error', unknown: 'Other error' } },
          { output_artifacts: { result: 'ok', logs: 'complete' } }
        ],
        output_artifacts_contracts: { result: 'Final result', logs: 'Execution logs' }
      )
      expect(agent.run).to include(result: 'ok', logs: 'complete')
      expect(agent.spy[:user_prompts].size).to eq(2)
      expect(agent.spy[:user_prompts][1]).to include('MISSING_PROMPT: logs (Execution logs) (Error: Parsing error)')
      expect(agent.spy[:user_prompts][1]).not_to include('unknown')
    end
  end

  describe 'conversation' do
    it 'records retry prompts when there are output artifact contracts and 1 retry' do
      agent = retriable_artifacts_agent(
        [
          { text: 'Assistant Output #1', output_artifacts: {} },
          { text: 'Assistant Output #2', output_artifacts: { result: 'complete', logs: 'success' } }
        ],
        output_artifacts_contracts: { result: 'Final result', logs: 'Execution logs' }
      )
      agent.run
      expect_conversation(
        agent.conversation,
        [
          { author: 'User', message: nil },
          { author: 'Agent Unnamed', message: /Assistant Output #1/ },
          { author: 'User', message: 'RENDERED_TEXT: MISSING_PROMPT: result (Final result), logs (Execution logs)' },
          { author: 'Agent Unnamed', message: /Assistant Output #2/ }
        ]
      )
    end

    it 'records retry prompts with the agent name when given' do
      agent = retriable_artifacts_agent(
        [
          { text: 'Assistant Output #1', output_artifacts: {} },
          { text: 'Assistant Output #2', output_artifacts: { result: 'complete', logs: 'success' } }
        ],
        name: 'Test Assistant',
        output_artifacts_contracts: { result: 'Final result', logs: 'Execution logs' }
      )
      agent.run
      expect_conversation(
        agent.conversation,
        [
          { author: 'User', message: nil },
          { author: 'Agent Test Assistant', message: /Assistant Output #1/ },
          { author: 'User', message: 'RENDERED_TEXT: MISSING_PROMPT: result (Final result), logs (Execution logs)' },
          { author: 'Agent Test Assistant', message: /Assistant Output #2/ }
        ]
      )
    end

    it 'records all retries when there are multiple missing artifacts, several retries and runs' do
      agent = retriable_artifacts_agent(
        [
          { text: 'Assistant Output #1', output_artifacts: {} },
          { text: 'Assistant Output #2', output_artifacts: { result: 'first' } },
          { text: 'Assistant Output #3', output_artifacts: { result: 'second', logs: 'final' } },
          { text: 'Assistant Output #4', output_artifacts: { result: 'second', logs: 'final' } }
        ],
        output_artifacts_contracts: { result: 'Final result', logs: 'Execution logs' }
      )
      agent.run
      agent.run(user_instructions: 'Again')
      expect_conversation(
        agent.conversation,
        [
          { author: 'User', message: nil },
          { author: 'Agent Unnamed', message: /Assistant Output #1/ },
          { author: 'User', message: 'RENDERED_TEXT: MISSING_PROMPT: result (Final result), logs (Execution logs)' },
          { author: 'Agent Unnamed', message: /Assistant Output #2/ },
          { author: 'User', message: 'RENDERED_TEXT: MISSING_PROMPT: logs (Execution logs)' },
          { author: 'Agent Unnamed', message: /Assistant Output #3/ },
          { author: 'User', message: 'RENDERED_TEXT: Again' },
          { author: 'Agent Unnamed', message: /Assistant Output #4/ }
        ]
      )
    end
  end
end
