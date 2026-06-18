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
      ARTIFACT_REPORT_content
      ```

      ```json output_artifact=ARTIFACT_SUMMARY
      ARTIFACT_SUMMARY_content
      ```

      ```json output_artifact=ARTIFACT_LOGS
      ARTIFACT_LOGS_content
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
      ARTIFACT_REPORT_content
      ```

      ```json output_artifact=ARTIFACT_SUMMARY
      ARTIFACT_SUMMARY_content
      ```

      ```json output_artifact=ARTIFACT_LOGS
      ARTIFACT_LOGS_content
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
      ARTIFACT_RESULT_content
      ```

      - You must return all those artifacts in your next response (MANDATORY).
    EO_PROMPT
  end

  it 'renders text type artifacts with text JSON template' do
    expect(
      agent_for_markdown_heavy(output_artifacts_contracts: { result: { description: 'The text result', type: :text } })
        .missing_output_user_instructions(
          result: { description: 'The text result' }
        )
    ).to eq <<~EO_PROMPT
      The following output artifacts are missing from your previous responses:
      - `ARTIFACT_RESULT`: The text result

      You must provide each one of them in your next response using embedded JSON blocks like this:

      ```json output_artifact=ARTIFACT_RESULT
      {"text":"ARTIFACT_RESULT_raw_text_content"}
      ```

      - You must return all those artifacts in your next response (MANDATORY).
    EO_PROMPT
  end

  it 'renders markdown type artifacts with markdown JSON template' do
    expect(
      agent_for_markdown_heavy(output_artifacts_contracts: { doc: { description: 'The markdown document', type: :markdown } })
        .missing_output_user_instructions(
          doc: { description: 'The markdown document' }
        )
    ).to eq <<~EO_PROMPT
      The following output artifacts are missing from your previous responses:
      - `ARTIFACT_DOC`: The markdown document

      You must provide each one of them in your next response using embedded JSON blocks like this:

      ```json output_artifact=ARTIFACT_DOC
      {"markdown":"ARTIFACT_DOC_markdown_content"}
      ```

      - You must return all those artifacts in your next response (MANDATORY).
    EO_PROMPT
  end

  it 'renders json type artifacts with raw JSON template' do
    expect(
      agent_for_markdown_heavy(output_artifacts_contracts: { data: { description: 'The JSON data', type: :json } })
        .missing_output_user_instructions(
          data: { description: 'The JSON data' }
        )
    ).to eq <<~EO_PROMPT
      The following output artifacts are missing from your previous responses:
      - `ARTIFACT_DATA`: The JSON data

      You must provide each one of them in your next response using embedded JSON blocks like this:

      ```json output_artifact=ARTIFACT_DATA
      {ARTIFACT_DATA_json_content}
      ```

      - You must return all those artifacts in your next response (MANDATORY).
    EO_PROMPT
  end

  it 'renders mixed type artifacts with appropriate templates' do
    expect(
      agent_for_markdown_heavy(
        output_artifacts_contracts: {
          text_result: { description: 'Text result', type: :text },
          md_report: { description: 'Markdown report', type: :markdown },
          raw_data: { description: 'JSON data', type: :json }
        }
      ).missing_output_user_instructions(
        text_result: { description: 'Text result' },
        md_report: { description: 'Markdown report' },
        raw_data: { description: 'JSON data' }
      )
    ).to eq <<~EO_PROMPT
      The following output artifacts are missing from your previous responses:
      - `ARTIFACT_TEXT_RESULT`: Text result
      - `ARTIFACT_MD_REPORT`: Markdown report
      - `ARTIFACT_RAW_DATA`: JSON data

      You must provide each one of them in your next response using embedded JSON blocks like this:

      ```json output_artifact=ARTIFACT_TEXT_RESULT
      {"text":"ARTIFACT_TEXT_RESULT_raw_text_content"}
      ```

      ```json output_artifact=ARTIFACT_MD_REPORT
      {"markdown":"ARTIFACT_MD_REPORT_markdown_content"}
      ```

      ```json output_artifact=ARTIFACT_RAW_DATA
      {ARTIFACT_RAW_DATA_json_content}
      ```

      - You must return all those artifacts in your next response (MANDATORY).
    EO_PROMPT
  end
end
