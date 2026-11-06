require 'fileutils'
require 'json'

describe ComposableAgents::Cline::Agent do
  describe 'context' do
    # Mocked session messages in which the assistant asks a question with some options, then uses a tool without any question.
    # The question is not the last message, as a plain Cline agent can't answer questions.
    # Note: the options given in the mocked messages are parsed by the Cline Rubygem as a Shale collection, not as a plain Array.
    # Note: the tool_use without a question is dropped from the context as it carries no useful content.
    let(:messages_with_question) do
      [
        {
          ts: 100,
          role: 'assistant',
          content: [
            {
              type: 'tool_use',
              id: 'tool_use_1',
              name: 'ask_question',
              input: { question: 'Which approach?', options: %w[Direct Indirect] }
            }
          ]
        },
        {
          ts: 101,
          role: 'assistant',
          content: [
            {
              type: 'tool_use',
              id: 'tool_use_2',
              name: 'run_commands',
              input: { commands: ['ls'] }
            }
          ]
        },
        {
          ts: 102,
          role: 'assistant',
          content: [{ type: 'text', text: 'Assistant Output #1' }]
        }
      ]
    end

    # Mocked session message in which a tool returns structured (non-String) content.
    # In cline-rb >= 2.3 such tool_result content is deserialized as a Shale collection of
    # Cline::SessionMessage::MessageContent::ToolResultContent objects, which JSON can't serialize directly.
    let(:messages_with_structured_tool_result) do
      [
        {
          ts: 200,
          role: 'assistant',
          content: [
            {
              type: 'tool_result',
              tool_use_id: 'tool_use_1',
              content: [
                { query: 'ls', result: 'a.txt', success: true },
                { query: 'cat a.txt', result: 'hello' }
              ]
            }
          ]
        },
        {
          ts: 201,
          role: 'assistant',
          content: [{ type: 'text', text: 'Assistant Output #1' }]
        }
      ]
    end

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
          #{JSON.pretty_generate [
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
      expect(JSON.parse(JSON.dump(state))).to eq state

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
          #{JSON.pretty_generate [
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
          #{JSON.pretty_generate [
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
          #{JSON.pretty_generate [
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

    it 'includes the context again in subsequent runs' do
      agent = cline_agent
      mock_cline_for(
        agent,
        [
          { stdout: 'Assistant Output #1' },
          { stdout: 'Assistant Output #2' },
          { stdout: 'Assistant Output #3' }
        ]
      )
      agent.run(user_instructions: 'Instructions #1')
      agent.run(user_instructions: 'Instructions #2')
      agent.run(user_instructions: 'Instructions #3')
      expect(agent.spy[:user_prompts]).to eq [
        'USER_PROMPT[RENDERED_TEXT: Instructions #1]',
        <<~EO_USER_PROMPT.strip,
          # Previous sessions context

          Here is the conversation from a previous session for context:

          ```json
          #{JSON.pretty_generate [
            {
              role: 'user',
              content: [{ type: 'text', text: 'USER_PROMPT[RENDERED_TEXT: Instructions #1]' }]
            },
            {
              role: 'assistant',
              content: [{ type: 'text', text: 'Assistant Output #1' }]
            }
          ]}
          ```

          Continue with the task, building on the work from the session above.

          USER_PROMPT[RENDERED_TEXT: Instructions #2]
        EO_USER_PROMPT
        <<~EO_USER_PROMPT.strip
          # Previous sessions context

          Here is the conversation from a previous session for context:

          ```json
          #{JSON.pretty_generate [
            {
              role: 'user',
              content: [{ type: 'text', text: 'USER_PROMPT[RENDERED_TEXT: Instructions #1]' }]
            },
            {
              role: 'assistant',
              content: [{ type: 'text', text: 'Assistant Output #1' }]
            },
            {
              role: 'user',
              content: [{ type: 'text', text: 'USER_PROMPT[RENDERED_TEXT: Instructions #2]' }]
            },
            {
              role: 'assistant',
              content: [{ type: 'text', text: 'Assistant Output #2' }]
            }
          ]}
          ```

          Continue with the task, building on the work from the session above.

          USER_PROMPT[RENDERED_TEXT: Instructions #3]
        EO_USER_PROMPT
      ]
    end

    it 'includes the options of the questions asked by the assistant in the context given to the next run' do
      agent = cline_agent
      mock_cline_for(
        agent,
        [
          { messages: messages_with_question },
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
          #{JSON.pretty_generate [
            {
              role: 'user',
              content: [{ type: 'text', text: 'USER_PROMPT[RENDERED_TEXT: First message]' }]
            },
            {
              role: 'assistant',
              content: [{ type: 'tool_use', input: { question: 'Which approach?', options: %w[Direct Indirect] } }]
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

    it 'persists the options of the questions asked by the assistant through a JSON-serializable state' do
      agent1 = cline_agent
      mock_cline_for(agent1, { messages: messages_with_question })
      agent1.run(user_instructions: 'First message')
      state = agent1.export_state
      # Options should be plain Ruby objects: the ones given by the Cline Rubygem are Shale objects that JSON can't serialize.
      expect(state['context'][1]['content'].first['input']['options']).to be_an_instance_of(Array)
      # Check that the context is JSON-serializable, as it is when saved by the Resumable mixin
      persisted_state = JSON.parse(JSON.dump(state))
      expect(persisted_state).to eq state
      # The tool_use without any question is dropped from the context, as it carries no useful content
      expect(persisted_state['context']).to eq [
        { 'role' => 'user', 'content' => [{ 'type' => 'text', 'text' => 'USER_PROMPT[RENDERED_TEXT: First message]' }] },
        {
          'role' => 'assistant',
          'content' => [{ 'type' => 'tool_use', 'input' => { 'question' => 'Which approach?', 'options' => %w[Direct Indirect] } }]
        },
        { 'role' => 'assistant', 'content' => [{ 'type' => 'text', 'text' => 'Assistant Output #1' }] }
      ]

      agent2 = cline_agent
      agent2.import_state(persisted_state)
      expect(agent2.export_state).to eq persisted_state
    end

    it 'persists structured tool results through a JSON-serializable state' do
      agent1 = cline_agent
      mock_cline_for(agent1, { messages: messages_with_structured_tool_result })
      agent1.run(user_instructions: 'First message')
      state = agent1.export_state
      # Structured tool_result content should be plain Ruby objects: the ones given by the Cline
      # Rubygem are Shale collections that JSON can't serialize.
      expect(state['context'][1]['content'].first['content']).to be_an_instance_of(Array)
      expect(state['context'][1]['content'].first['content'].first).to be_an_instance_of(Hash)
      # Check that the context is JSON-serializable, as it is when saved by the Resumable mixin
      persisted_state = JSON.parse(JSON.dump(state))
      expect(persisted_state).to eq state
      expect(persisted_state['context'][1]['content'].first['content']).to eq [
        { 'query' => 'ls', 'result' => 'a.txt', 'success' => true },
        { 'query' => 'cat a.txt', 'result' => 'hello', 'success' => nil }
      ]

      agent2 = cline_agent
      agent2.import_state(persisted_state)
      expect(agent2.export_state).to eq persisted_state
    end

    it 'keeps the thinking content of messages in the context given to the next run' do
      agent = cline_agent
      mock_cline_for(
        agent,
        [
          {
            messages: [
              {
                ts: 100,
                role: 'assistant',
                content: [
                  { type: 'thinking', thinking: 'Assistant Thinking #1' },
                  { type: 'text', text: 'Assistant Output #1' }
                ]
              }
            ]
          },
          { stdout: 'Assistant Output #2' }
        ]
      )
      agent.run(user_instructions: 'First message')
      agent.run(user_instructions: 'Second message')
      # Extract the context from the second prompt and check the thinking content is preserved in it
      context = JSON.parse(agent.spy[:user_prompts].last[/```json\n(.+?)\n```/m, 1])
      expect(context).to eq [
        { 'role' => 'user', 'content' => [{ 'type' => 'text', 'text' => 'USER_PROMPT[RENDERED_TEXT: First message]' }] },
        {
          'role' => 'assistant',
          'content' => [
            { 'type' => 'thinking', 'text' => 'Assistant Thinking #1' },
            { 'type' => 'text', 'text' => 'Assistant Output #1' }
          ]
        }
      ]
    end

    it 'drops content blocks having no useful content from the context given to the next run' do
      agent = cline_agent
      mock_cline_for(
        agent,
        [
          {
            messages: [
              {
                ts: 100,
                role: 'assistant',
                content: [
                  # A tool_use block without any input carries no useful content: it is dropped from the context.
                  { type: 'tool_use', name: 'run_commands' },
                  { type: 'text', text: 'Assistant Output #1' }
                ]
              }
            ]
          },
          { stdout: 'Assistant Output #2' }
        ]
      )
      agent.run(user_instructions: 'First message')
      agent.run(user_instructions: 'Second message')
      # Extract the context from the second prompt: only the text content block is kept in the assistant message
      context = JSON.parse(agent.spy[:user_prompts].last[/```json\n(.+?)\n```/m, 1])
      expect(context).to eq [
        { 'role' => 'user', 'content' => [{ 'type' => 'text', 'text' => 'USER_PROMPT[RENDERED_TEXT: First message]' }] },
        { 'role' => 'assistant', 'content' => [{ 'type' => 'text', 'text' => 'Assistant Output #1' }] }
      ]
    end
  end
end
