describe ComposableAgents::PromptRenderingStrategy::MarkdownHeavy, '#missing_output_user_instructions' do
  it 'prompts for missing artifacts' do
    expect(
      agent_for_markdown_heavy.missing_output_user_instructions(
        report: { description: 'Final report document' },
        summary: { description: 'Executive summary' },
        logs: { description: 'Execution logs' }
      )
    ).to eq <<~EO_PROMPT
      The following output artifacts are missing from your previous responses:
      - `ARTIFACT_REPORT`: Final report document
      - `ARTIFACT_SUMMARY`: Executive summary
      - `ARTIFACT_LOGS`: Execution logs

      You must provide each one of them in your next response using embedded JSON blocks like this:

      ```json output_artifact=ARTIFACT_REPORT
      {ARTIFACT_REPORT artifact content}
      ```

      ```json output_artifact=ARTIFACT_SUMMARY
      {ARTIFACT_SUMMARY artifact content}
      ```

      ```json output_artifact=ARTIFACT_LOGS
      {ARTIFACT_LOGS artifact content}
      ```

      - You must return all those artifacts in your next response (MANDATORY).
    EO_PROMPT
  end

  it 'includes error information when artifacts have errors' do
    expect(
      agent_for_markdown_heavy.missing_output_user_instructions(
        report: { description: 'Final report document', error: 'Could not parse artifact content: unexpected token at line 3' },
        summary: { description: 'Executive summary' },
        logs: { description: 'Execution logs', error: 'File not found' }
      )
    ).to eq <<~EO_PROMPT
      The following output artifacts are missing from your previous responses:
      - `ARTIFACT_REPORT`: Final report document
        An error occurred while reading this artifact from your previous responses: Could not parse artifact content: unexpected token at line 3
      - `ARTIFACT_SUMMARY`: Executive summary
      - `ARTIFACT_LOGS`: Execution logs
        An error occurred while reading this artifact from your previous responses: File not found

      You must provide each one of them in your next response using embedded JSON blocks like this:

      ```json output_artifact=ARTIFACT_REPORT
      {ARTIFACT_REPORT artifact content}
      ```

      ```json output_artifact=ARTIFACT_SUMMARY
      {ARTIFACT_SUMMARY artifact content}
      ```

      ```json output_artifact=ARTIFACT_LOGS
      {ARTIFACT_LOGS artifact content}
      ```

      - You must return all those artifacts in your next response (MANDATORY).
    EO_PROMPT
  end

  it 'handles single missing artifact correctly' do
    expect(
      agent_for_markdown_heavy.missing_output_user_instructions(
        result: { description: 'Calculation result' }
      )
    ).to eq <<~EO_PROMPT
      The following output artifacts are missing from your previous responses:
      - `ARTIFACT_RESULT`: Calculation result

      You must provide each one of them in your next response using embedded JSON blocks like this:

      ```json output_artifact=ARTIFACT_RESULT
      {ARTIFACT_RESULT artifact content}
      ```

      - You must return all those artifacts in your next response (MANDATORY).
    EO_PROMPT
  end
end
