module ComposableAgentsTest
  module Helpers
    # Provide helpers for Cline agent tests
    module Cline
      # @return [ClineTest::CliStub] The Cline CLI stub that is used in tests
      attr_reader :cli_stub

      # Mock a Cline CLI execution process for a given agent.
      # This will use the ClineTest CLI stub and set spies in an agent for expectations.
      #
      # @param agent [ComposableAgents::Agent] The agent to be used to spy on Cline CLI
      # @param mocked_run_results [Array<Hash{Symbol => Object}>, Hash{Symbol => Object}] List of (or single)
      #   mocked results that will be returned by the stub, for each call to the stub.
      #   Possible attributes of a mocked result are the ones of mocked_assistant_outputs (see prompt_driven_agent_examples.rb),
      #   and also the following ones:
      #   - stub [Object] The Cline CLI stub instructions (see ClineTest::CliStub#mock_commands).
      def mock_cline_for(agent, mocked_run_results = [])
        mocked_run_results = [mocked_run_results] unless mocked_run_results.is_a?(Array)
        @cli_stub = ClineTest::CliStub.new(
          example: self,
          debug: ComposableAgentsTest::Helpers::Debug.debug?,
          temp_dir: '.composable_agents_test/cline_stub'
        )
        cli_stub.mock_commands(
          mocked_run_results.map do |mocked_run_result|
            [
              {
                log: {},
                session: {
                  messages: [{ ts: 100, content: [{ text: mocked_run_result[:stdout] || 'Assistant Output' }] }]
                }
              }
            ] +
              (
                if mocked_run_result[:stub]
                  mocked_run_result[:stub].is_a?(Array) ? mocked_run_result[:stub] : [mocked_run_result[:stub]]
                else
                  []
                end
              ) +
              [{ exit: mocked_run_result[:exit_status] || 0 }]
          end
        )
        # Add spies to the agent for the mock to work properly and make it inspectable.
        class << agent
          include ComposableAgentsTest::ClineAgentSpies
        end
        agent.cli_stub = cli_stub
      end

      # Convert the desired mocked outputs to the Cline mocked outputs
      #
      # @param mocked_assistant_outputs [Array<Object>, Object] List of (or single) assistant outputs (see shared examples)
      # @return [Array<Hash{Symbol => Object}>] The corresponding Cline mocked results
      def mocked_outputs_to_cline_outputs(mocked_assistant_outputs)
        # Normalize the mocked outputs
        (mocked_assistant_outputs.is_a?(Array) ? mocked_assistant_outputs : [mocked_assistant_outputs]).map do |desc|
          desc = { text: desc } unless desc.is_a?(Hash)
          stdout = desc[:text] || ''
          if desc[:output_artifacts] && !desc[:output_artifacts].empty?
            stdout << "\n\n"
            stdout << (desc[:output_artifacts] || {}).map do |artifact_name, artifact_content|
              <<~EO_STDOUT
                ```json artifact=ARTIFACT_#{artifact_name.to_s.upcase}
                #{artifact_content.to_json}
                ```
              EO_STDOUT
            end.join("\n")
          end
          {
            stdout:,
            exit_status: 0
          }
        end
      end
    end
  end
end
