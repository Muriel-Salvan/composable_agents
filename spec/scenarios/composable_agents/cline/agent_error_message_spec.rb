describe ComposableAgents::Cline::Agent do
  describe 'error handling on a failed Cline CLI run' do
    let(:agent) { cline_agent }

    it 'raises with the structured err message extracted from the error log' do
      mock_cline_for(
        agent,
        {
          log: { level: 40, err: { message: 'max consecutive mistakes reached (3) in yolo mode' } },
          session: { status: 'failed' },
          exit: 1
        }
      )
      expect { agent.run(user_instructions: 'Do something') }
        .to raise_error(/Error: max consecutive mistakes reached \(3\) in yolo mode/)
    end

    it 'raises with the error_message attribute when no err field is present' do
      mock_cline_for(
        agent,
        {
          log: { level: 40, errorMessage: 'max consecutive mistakes reached (3) in yolo mode' },
          session: { status: 'failed' },
          exit: 1
        }
      )
      expect { agent.run(user_instructions: 'Do something') }
        .to raise_error(/Error: max consecutive mistakes reached \(3\) in yolo mode/)
    end

    it 'falls back to error_name when neither err nor error_message is present' do
      mock_cline_for(
        agent,
        {
          log: { level: 40, errorName: 'AgentRuntimeAbortError' },
          session: { status: 'failed' },
          exit: 1
        }
      )
      expect { agent.run(user_instructions: 'Do something') }
        .to raise_error(/Error: AgentRuntimeAbortError/)
    end

    it 'raises with the msg fallback when the error log has no err field' do
      mock_cline_for(
        agent,
        {
          log: { level: 40, msg: 'Something went wrong' },
          session: { status: 'failed' },
          exit: 1
        }
      )
      expect { agent.run(user_instructions: 'Do something') }.to raise_error(/Error: Something went wrong/)
    end
  end
end
