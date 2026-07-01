require_relative '../shared_examples/prompt_driven_agent_examples'
require_relative '../shared_examples/prompt_driven_agent_with_contracts_examples'
require 'fileutils'

describe ComposableAgents::Cline::Agent do
  it_behaves_like(
    'a prompt driven agent',
    new_agent: proc do |example, mocked_assistant_outputs: [], **kwargs|
      example.instance_eval do
        agent = described_class.new(
          composable_agents_dir: '.composable_agents_test',
          provider: 'test-provider',
          model: 'test-model',
          **kwargs
        )
        mock_cline_for(
          agent,
          mocked_outputs_to_cline_outputs(mocked_assistant_outputs)
        )
        agent
      end
    end,
    contracts: true,
    default_conversation_name: 'Agent Unnamed (Cline test-provider/test-model)',
    named_agent_conversation_name: 'Agent Test Assistant (Cline test-provider/test-model)'
  )

  it_behaves_like(
    'a prompt driven agent with artifacts contracts',
    new_agent: proc do |example, mocked_assistant_outputs: [], **kwargs|
      example.instance_eval do
        agent = described_class.new(
          composable_agents_dir: '.composable_agents_test',
          provider: 'test-provider',
          model: 'test-model',
          **kwargs
        )
        mock_cline_for(
          agent,
          mocked_outputs_to_cline_outputs(mocked_assistant_outputs)
        )
        agent
      end
    end,
    default_conversation_name: 'Agent Unnamed (Cline test-provider/test-model)',
    named_agent_conversation_name: 'Agent Test Assistant (Cline test-provider/test-model)'
  )

  describe 'dedicated config directory' do
    it 'uses a dedicated directory to run the Cline CLI config' do
      agent = cline_agent
      mock_cline_for(
        agent,
        {
          stdout: {
            eval: <<~EO_RUBY
              config_dir
            EO_RUBY
          }
        }
      )
      agent.run
      used_config_dir = agent.conversation.last[:message]
      expect(used_config_dir).not_to eq Cline::Config.global&.dir
      # Could be that project dir does not exist. Check all possible cases.
      expect(used_config_dir).not_to eq Cline::Config.project&.dir
      expect(used_config_dir).not_to eq '.cline'
    end
  end
end
