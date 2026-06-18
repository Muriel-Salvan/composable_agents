describe ComposableAgents::Cline::Agent do
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

  describe 'output artifacts' do
    it 'gets output artifacts from any message produced by Cline' do
      agent = described_agent(output_artifacts_contracts: { result: 'Final result', logs: 'Execution logs' })
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

    it 'gracefully fails when output artifact JSON parsing fails' do
      agent = described_agent(output_artifacts_contracts: { result: 'Final result', logs: 'Execution logs' })
      mock_cline_for(
        agent,
        [
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
                        text: <<~EO_OUTPUT
                          Assistant Output #3
                          ```json output_artifact=ARTIFACT_LOGS
                          Wrong JSON
                          ```
                        EO_OUTPUT
                      },
                      {
                        type: 'text',
                        text: <<~EO_OUTPUT
                          Assistant Output #6
                          ```json output_artifact=ARTIFACT_RESULT
                          "ok"
                          ```
                        EO_OUTPUT
                      }
                    ]
                  }
                ]
              }
            }
          },
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
                        text: <<~EO_OUTPUT
                          Assistant Output #3
                          ```json output_artifact=ARTIFACT_LOGS
                          Wrong JSON
                          ```
                        EO_OUTPUT
                      },
                      {
                        type: 'text',
                        text: <<~EO_OUTPUT
                          Assistant Output #6
                          ```json output_artifact=ARTIFACT_RESULT
                          "ok"
                          ```
                        EO_OUTPUT
                      }
                    ]
                  },
                  {
                    ts: 300,
                    role: 'assistant',
                    content: [
                      {
                        type: 'text',
                        text: <<~EO_OUTPUT
                          Assistant Output #3
                          ```json output_artifact=ARTIFACT_LOGS
                          "logs"
                          ```
                        EO_OUTPUT
                      }
                    ]
                  }
                ]
              }
            }
          }
        ]
      )
      expect(agent.run).to include(result: 'ok', logs: 'logs')
      expect(agent.spy[:user_prompts]).to eq [
        'USER_PROMPT[]',
        'USER_PROMPT[RENDERED_TEXT: MISSING_PROMPT: logs (Execution logs) (Error: unexpected character: \'Wrong\' at line 1 column 1)]'
      ]
    end
  end
end
