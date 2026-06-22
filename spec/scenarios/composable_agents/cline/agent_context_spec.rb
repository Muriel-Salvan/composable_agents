require 'fileutils'
require 'json'

describe ComposableAgents::Cline::Agent do
  describe 'context' do
    it 'has an empty context at the beginning of the first run' do
      agent = cline_agent
      mock_cline_for(agent)
      agent.run(user_instructions: 'First message')
      expect(agent.spy[:user_prompts]).to eq ['USER_PROMPT[RENDERED_TEXT: First message]']
    end

    it 'accumulates context over several runs' do
      agent = cline_agent
      mock_cline_for(
        agent,
        [
          { stdout: 'Assistant Output #1' },
          { stdout: 'Assistant Output #2' }
        ]
      )
      agent.run(user_instructions: 'First message')
      agent.run(user_instructions: 'Second message')
      expect(agent.spy[:user_prompts]).to eq [
        'USER_PROMPT[RENDERED_TEXT: First message]',
        <<~EO_USER_PROMPT.strip
          # Previous sessions context

          Here is the conversation from a previous session for context:

          ```json
          #{JSON.dump [
            {
              role: 'user',
              content: [{ type: 'text', text: 'USER_PROMPT[RENDERED_TEXT: First message]' }]
            },
            {
              role: 'assistant',
              content: [{ type: 'text', text: 'Assistant Output #1' }]
            }
          ]}
          ```

          Continue with the task, building on the work from the session above.

          USER_PROMPT[RENDERED_TEXT: Second message]
        EO_USER_PROMPT
      ]
    end

    it 'persists the context through a JSON-serializable state' do
      agent1 = cline_agent
      mock_cline_for(
        agent1,
        [
          { stdout: 'Assistant Output #1' },
          { stdout: 'Assistant Output #2' }
        ]
      )
      agent1.run(user_instructions: 'First message')
      agent1.run(user_instructions: 'Second message')
      state = agent1.export_state
      # Check that context is JSON-serializable
      expect { JSON.parse(state.to_json) }.not_to raise_error

      agent2 = cline_agent
      mock_cline_for(
        agent2,
        [
          { stdout: 'Assistant Output #3' },
          { stdout: 'Assistant Output #4' }
        ]
      )
      agent2.import_state(state)
      expect(agent2.export_state).to eq state
      # Second agent's run should have the context from the first agent's runs
      agent2.run(user_instructions: 'Third message')
      agent2.run(user_instructions: 'Fourth message')
      expect(agent2.spy[:user_prompts]).to eq [
        'USER_PROMPT[RENDERED_TEXT: First message]',
        <<~EO_USER_PROMPT.strip,
          # Previous sessions context

          Here is the conversation from a previous session for context:

          ```json
          #{JSON.dump [
            {
              role: 'user',
              content: [{ type: 'text', text: 'USER_PROMPT[RENDERED_TEXT: First message]' }]
            },
            {
              role: 'assistant',
              content: [{ type: 'text', text: 'Assistant Output #1' }]
            }
          ]}
          ```

          Continue with the task, building on the work from the session above.

          USER_PROMPT[RENDERED_TEXT: Second message]
        EO_USER_PROMPT
        <<~EO_USER_PROMPT.strip,
          # Previous sessions context

          Here is the conversation from a previous session for context:

          ```json
          #{JSON.dump [
            {
              role: 'user',
              content: [{ type: 'text', text: 'USER_PROMPT[RENDERED_TEXT: First message]' }]
            },
            {
              role: 'assistant',
              content: [{ type: 'text', text: 'Assistant Output #1' }]
            },
            {
              role: 'user',
              content: [{ type: 'text', text: 'USER_PROMPT[RENDERED_TEXT: Second message]' }]
            },
            {
              role: 'assistant',
              content: [{ type: 'text', text: 'Assistant Output #2' }]
            }
          ]}
          ```

          Continue with the task, building on the work from the session above.

          USER_PROMPT[RENDERED_TEXT: Third message]
        EO_USER_PROMPT
        <<~EO_USER_PROMPT.strip
          # Previous sessions context

          Here is the conversation from a previous session for context:

          ```json
          #{JSON.dump [
            {
              role: 'user',
              content: [{ type: 'text', text: 'USER_PROMPT[RENDERED_TEXT: First message]' }]
            },
            {
              role: 'assistant',
              content: [{ type: 'text', text: 'Assistant Output #1' }]
            },
            {
              role: 'user',
              content: [{ type: 'text', text: 'USER_PROMPT[RENDERED_TEXT: Second message]' }]
            },
            {
              role: 'assistant',
              content: [{ type: 'text', text: 'Assistant Output #2' }]
            },
            {
              role: 'user',
              content: [{ type: 'text', text: 'USER_PROMPT[RENDERED_TEXT: Third message]' }]
            },
            {
              role: 'assistant',
              content: [{ type: 'text', text: 'Assistant Output #3' }]
            }
          ]}
          ```

          Continue with the task, building on the work from the session above.

          USER_PROMPT[RENDERED_TEXT: Fourth message]
        EO_USER_PROMPT
      ]
    end

    it 'does not duplicate context given between runs' do
      agent = cline_agent
      mock_cline_for(
        agent,
        [
          { stdout: 'Assistant Output #1' },
          { stdout: 'Assistant Output #2' },
          { stdout: 'Assistant Output #3' }
        ]
      )
      agent.run(user_instructions: 'User Input #1')
      agent.run(user_instructions: 'User Input #2')
      agent.run(user_instructions: 'User Input #3')
      expect(agent.spy[:user_prompts].last).to include('Assistant Output #1').once
    end

    it 'includes the context again in missing output artifacts prompts' do
      agent = cline_agent(output_artifacts_contracts: { result: 'Final result' })
      mock_cline_for(
        agent,
        [
          {
            stdout: 'Assistant Output #1'
          },
          {
            stdout: <<~EO_OUTPUT
              Assistant Output #2
              ```json output_artifact=ARTIFACT_RESULT
              "ok"
              ```
            EO_OUTPUT
          }
        ]
      )
      agent.run
      expect(agent.spy[:user_prompts]).to eq [
        'USER_PROMPT[]',
        <<~EO_USER_PROMPT.strip
          # Previous sessions context

          Here is the conversation from a previous session for context:

          ```json
          #{JSON.dump [
            {
              role: 'user',
              content: [{ type: 'text', text: 'USER_PROMPT[]' }]
            },
            {
              role: 'assistant',
              content: [{ type: 'text', text: 'Assistant Output #1' }]
            }
          ]}
          ```

          Continue with the task, building on the work from the session above.

          USER_PROMPT[RENDERED_TEXT: MISSING_PROMPT: result (Final result)]
        EO_USER_PROMPT
      ]
    end
  end
end
