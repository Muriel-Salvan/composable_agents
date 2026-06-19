describe ComposableAgents::PromptRenderingStrategy::MarkdownHeavy, '#parse_output_artifacts' do
  let(:output_contracts) { {} }
  let(:agent) do
    new_agent = agent_for_markdown_heavy(output_artifacts_contracts: output_contracts)
    # Set this variables manually as those test cases won't use run.
    new_agent.output_artifacts = {}
    new_agent.output_artifacts_errors = {}
    new_agent
  end

  describe 'with 1 output artifact not having type information' do
    let(:output_contracts) { { report: { description: 'Final report' } } }

    it 'parses the artifact correctly' do
      agent.parse_output_artifacts <<~EO_TEXT
        ```json output_artifact=ARTIFACT_REPORT
        {"title": "My Report", "section": "Introduction"}
        ```
      EO_TEXT
      expect(agent.output_artifacts).to eq(report: { 'title' => 'My Report', 'section' => 'Introduction' })
      expect(agent.output_artifacts_errors).to be_empty
    end

    it 'reports the error correctly when JSON cannot be parsed' do
      agent.parse_output_artifacts <<~EO_TEXT
        ```json output_artifact=ARTIFACT_REPORT
        not valid json
        ```
      EO_TEXT
      expect(agent.output_artifacts).to be_empty
      expect(agent.output_artifacts_errors).to eq(report: 'unexpected token \'not\' at line 1 column 1')
    end
  end

  describe 'with 1 output artifact of type text' do
    let(:output_contracts) { { result: { description: 'Text result', type: :text } } }

    it 'parses the artifact correctly' do
      agent.parse_output_artifacts <<~EO_TEXT
        ```json output_artifact=ARTIFACT_RESULT
        {"text": "My text result"}
        ```
      EO_TEXT
      expect(agent.output_artifacts).to eq(result: 'My text result')
      expect(agent.output_artifacts_errors).to be_empty
    end

    it 'reports the error correctly when JSON cannot be parsed' do
      agent.parse_output_artifacts <<~EO_TEXT
        ```json output_artifact=ARTIFACT_RESULT
        not valid json
        ```
      EO_TEXT
      expect(agent.output_artifacts).to be_empty
      expect(agent.output_artifacts_errors).to eq(result: 'unexpected token \'not\' at line 1 column 1')
    end

    it 'reports errors correctly when text key is missing' do
      agent.parse_output_artifacts <<~EO_TEXT
        ```json output_artifact=ARTIFACT_RESULT
        {"content": "My text result"}
        ```
      EO_TEXT
      expect(agent.output_artifacts).to be_empty
      expect(agent.output_artifacts_errors).to eq(
        result: 'Missing required key "text" containing the artifact text content in the JSON artifact response.'
      )
    end

    it 'reports errors correctly when text value is not a string' do
      agent.parse_output_artifacts <<~EO_TEXT
        ```json output_artifact=ARTIFACT_RESULT
        {"text": 123}
        ```
      EO_TEXT
      expect(agent.output_artifacts).to be_empty
      expect(agent.output_artifacts_errors).to eq(
        result: 'Wrong format for artifact content in key "text": expecting a raw String but got Integer instead.'
      )
    end
  end

  describe 'with 1 output artifact of type markdown' do
    let(:output_contracts) { { doc: { description: 'Markdown document', type: :markdown } } }

    it 'parses the artifact correctly' do
      agent.parse_output_artifacts <<~EO_TEXT
        ```json output_artifact=ARTIFACT_DOC
        {"markdown": "# Title\\n\\nBody text"}
        ```
      EO_TEXT
      expect(agent.output_artifacts).to eq(doc: "# Title\n\nBody text")
      expect(agent.output_artifacts_errors).to be_empty
    end

    it 'reports the error correctly when JSON cannot be parsed' do
      agent.parse_output_artifacts <<~EO_TEXT
        ```json output_artifact=ARTIFACT_DOC
        not valid json
        ```
      EO_TEXT
      expect(agent.output_artifacts).to be_empty
      expect(agent.output_artifacts_errors).to eq(doc: 'unexpected token \'not\' at line 1 column 1')
    end

    it 'reports errors correctly when markdown key is missing' do
      agent.parse_output_artifacts <<~EO_TEXT
        ```json output_artifact=ARTIFACT_DOC
        {"content": "# Title"}
        ```
      EO_TEXT
      expect(agent.output_artifacts).to be_empty
      expect(agent.output_artifacts_errors).to eq(
        doc: 'Missing required key "markdown" containing the artifact Markdown content in the JSON artifact response.'
      )
    end

    it 'reports errors correctly when markdown value is not a string' do
      agent.parse_output_artifacts <<~EO_TEXT
        ```json output_artifact=ARTIFACT_DOC
        {"markdown": ["# Title"]}
        ```
      EO_TEXT
      expect(agent.output_artifacts).to be_empty
      expect(agent.output_artifacts_errors).to eq(
        doc: 'Wrong format for artifact content in key "markdown": ' \
          'expecting a Markdown string but got Array instead.'
      )
    end
  end

  describe 'with 1 output artifact of type json' do
    let(:output_contracts) { { data: { description: 'JSON data', type: :json } } }

    it 'parses the artifact correctly' do
      agent.parse_output_artifacts <<~EO_TEXT
        ```json output_artifact=ARTIFACT_DATA
        {"users": [{"name": "Alice"}], "count": 1}
        ```
      EO_TEXT
      expect(agent.output_artifacts).to eq(data: { 'users' => [{ 'name' => 'Alice' }], 'count' => 1 })
      expect(agent.output_artifacts_errors).to be_empty
    end

    it 'reports the error correctly when JSON cannot be parsed' do
      agent.parse_output_artifacts <<~EO_TEXT
        ```json output_artifact=ARTIFACT_DATA
        not valid json
        ```
      EO_TEXT
      expect(agent.output_artifacts).to be_empty
      expect(agent.output_artifacts_errors).to eq(data: 'unexpected token \'not\' at line 1 column 1')
    end
  end

  describe 'with several output artifacts of various types' do
    let(:output_contracts) do
      {
        report: { description: 'Text report', type: :text },
        doc: { description: 'Markdown doc', type: :markdown },
        data: { description: 'JSON data', type: :json },
        blob: { description: 'Any data' }
      }
    end

    it 'parses all of them from 1 text message' do
      agent.parse_output_artifacts <<~EO_TEXT
        Before

        ```json output_artifact=ARTIFACT_REPORT
        {"text": "The report content"}
        ```

        ```json output_artifact=ARTIFACT_BLOB
        42
        ```

        Middle

        ```json output_artifact=ARTIFACT_DOC
        {"markdown": "## Document"}
        ```

        ```json output_artifact=ARTIFACT_DATA
        {"key": "value"}
        ```

        After
      EO_TEXT
      expect(agent.output_artifacts).to eq(
        report: 'The report content',
        doc: '## Document',
        data: { 'key' => 'value' },
        blob: 42
      )
      expect(agent.output_artifacts_errors).to be_empty
    end
  end
end
