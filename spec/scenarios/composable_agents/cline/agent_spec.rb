require_relative '../shared_examples/prompt_driven_agent_examples'
require_relative '../shared_examples/prompt_driven_agent_with_contracts_examples'
require 'fileutils'
# Require the Cline CLI stub provided by the cline-rb Rubygem
require "#{Gem.loaded_specs['cline-rb'].full_gem_path}/spec/cline_test/cli_stub"

describe ComposableAgents::Cline::Agent do
  # @return [ClineTest::CliStub] The Cline CLI stub that is used in tests
  attr_reader :cli_stub

  # Mock a Cline CLI execution process for a given agent.
  # This will use the ClineTest CLI stub and set spies in an agent for expectations.
  #
  # @param agent [ComposableAgents::Agent] The agent to be used to spy on Cline CLI
  # @param mocked_run_results [Array<Hash{Symbol => Object}>, Hash{Symbol => Object}] List of (or single)
  #   mocked results that will be returned by the stub, for each call to the stub.
  def mock_cline_for(agent, mocked_run_results = [])
    mocked_run_results = [mocked_run_results] unless mocked_run_results.is_a?(Array)
    @cli_stub = ClineTest::CliStub.new(
      example: self,
      debug: ComposableAgentsTest::Helpers.debug?,
      temp_dir: '.composable_agents_test/cline_stub'
    )
    cli_stub.mock_commands(
      mocked_run_results.map do |mocked_run_result|
        {
          log: {},
          session: {
            messages: [{ ts: 100, content: [{ text: mocked_run_result[:stdout] }] }]
          },
          exit: mocked_run_result[:exit_status]
        }
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

  before do
    FileUtils.rm_rf('.composable_agents_test')
  end

  it_behaves_like(
    'a prompt driven agent',
    new_agent: proc do |example, mocked_assistant_outputs: [], **kwargs|
      example.instance_eval do
        agent = described_class.new(composable_agents_dir: '.composable_agents_test', **kwargs)
        mock_cline_for(
          agent,
          mocked_outputs_to_cline_outputs(mocked_assistant_outputs)
        )
        agent
      end
    end,
    contracts: true
  )

  it_behaves_like(
    'a prompt driven agent with artifacts contracts',
    new_agent: proc do |example, mocked_assistant_outputs: [], **kwargs|
      example.instance_eval do
        agent = described_class.new(composable_agents_dir: '.composable_agents_test', **kwargs)
        mock_cline_for(
          agent,
          mocked_outputs_to_cline_outputs(mocked_assistant_outputs)
        )
        agent
      end
    end
  )

  # Helper method to instantiate an Agent with test rendering strategy.
  #
  # @param params [Hash] Parameters to pass to the agent constructor.
  # @return [ComposableAgents::Agent] The agent
  def described_agent(**params)
    described_class.new(
      composable_agents_dir: '.composable_agents_test',
      strategy: ComposableAgentsTest::TestRenderingStrategy,
      **params
    )
  end
end
