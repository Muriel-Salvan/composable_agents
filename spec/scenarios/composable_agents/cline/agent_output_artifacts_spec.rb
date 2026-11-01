require 'English'

describe ComposableAgents::Cline::Agent do
  describe 'output artifacts' do
    it 'gets output artifacts from any message produced by Cline' do
      agent = cline_agent
      mock_cline_for(
        agent,
        {
          stub: {
            session: {
              messages: [
                {
                  ts: 200,
                  role: 'assistant',
                  content: [
                    {
                      type: 'text',
                      text: 'Assistant Output #2'
                    },
                    {
                      type: 'text',
                      text: <<~EO_OUTPUT
                        Assistant Output #3
                        ```json output_artifact=ARTIFACT_LOGS
                        "logs"
                        ```
                      EO_OUTPUT
                    },
                    {
                      type: 'text',
                      text: 'Assistant Output #4'
                    }
                  ]
                },
                {
                  ts: 300,
                  role: 'assistant',
                  content: [
                    {
                      type: 'text',
                      text: 'Assistant Output #5'
                    },
                    {
                      type: 'text',
                      text: <<~EO_OUTPUT
                        Assistant Output #6
                        ```json output_artifact=ARTIFACT_RESULT
                        "ok"
                        ```
                      EO_OUTPUT
                    },
                    {
                      type: 'text',
                      text: 'Assistant Output #7'
                    }
                  ]
                },
                {
                  ts: 400,
                  role: 'assistant',
                  content: [
                    {
                      type: 'text',
                      text: 'Assistant Output #8'
                    }
                  ]
                }
              ]
            }
          }
        }
      )
      expect(agent.run).to include(result: 'ok', logs: 'logs')
      expect(agent.spy[:user_prompts]).to eq ['USER_PROMPT[]']
    end
  end
end
