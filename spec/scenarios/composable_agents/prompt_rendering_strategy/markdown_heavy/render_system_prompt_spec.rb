describe ComposableAgents::PromptRenderingStrategy::MarkdownHeavy, '#render_system_prompt' do
  # Render the system prompt for a given agent's constructor parameters
  #
  # @param rendered_instructions [Array<String>] The rendered instructions
  # @param role [String, NilClass] Agent's role, or nil for default
  # @param input_artifacts_contracts [Hash<Symbol, Object>, NilClass] Hash of input artifact names and their contracts, or nil if none.
  # @param input_artifacts [Hash<Symbol, Object>] Hash of input artifact names and content to be given to the system prompt.
  # @param kwargs [Hash] The constructor parameters of the agent
  # @return [String] The rendered system prompt
  def system_prompt(
    rendered_instructions: ['Instruction 1', 'Instruction 2'],
    role: 'Test Agent Role',
    input_artifacts_contracts: nil,
    input_artifacts: {},
    **kwargs
  )
    agent_for_markdown_heavy(input_artifacts_contracts:, role:, **kwargs).render_system_prompt(rendered_instructions, input_artifacts:)
  end

  it 'includes role, instructions sections without input artifacts intro if there aren\'t any artifacts' do
    expect(system_prompt).to eq <<~EO_SYSTEM_PROMPT.strip
      # Role

      Test Agent Role

      # Instructions

      Instruction 1

      Instruction 2
    EO_SYSTEM_PROMPT
  end

  it 'levels big headers in roles properly' do
    expect(
      system_prompt(
        role: <<~EO_ROLE
          # Role Header 1

          ## 1. Role Header 1.1

          Test Agent Role
        EO_ROLE
      )
    ).to eq <<~EO_SYSTEM_PROMPT.strip
      # Role

      ## Role Header 1

      ### 1. Role Header 1.1

      Test Agent Role

      # Instructions

      Instruction 1

      Instruction 2
    EO_SYSTEM_PROMPT
  end

  it 'includes objective section when objective is present' do
    expect(
      system_prompt(objective: 'Complete the assigned task')
    ).to eq <<~EO_SYSTEM_PROMPT.strip
      # Role

      Test Agent Role

      # Objective

      Complete the assigned task

      # Instructions

      Instruction 1

      Instruction 2
    EO_SYSTEM_PROMPT
  end

  it 'omits objective section when objective is empty' do
    expect(
      system_prompt(objective: '')
    ).to eq <<~EO_SYSTEM_PROMPT.strip
      # Role

      Test Agent Role

      # Instructions

      Instruction 1

      Instruction 2
    EO_SYSTEM_PROMPT
  end

  it 'includes constraints section when constraints are present' do
    expect(
      system_prompt(constraints: 'Do not exceed token limits')
    ).to eq <<~EO_SYSTEM_PROMPT.strip
      # Role

      Test Agent Role

      # Instructions

      Instruction 1

      Instruction 2

      # Constraints

      Do not exceed token limits
    EO_SYSTEM_PROMPT
  end

  it 'omits constraints section when constraints are empty' do
    expect(
      system_prompt(constraints: '')
    ).to eq <<~EO_SYSTEM_PROMPT.strip
      # Role

      Test Agent Role

      # Instructions

      Instruction 1

      Instruction 2
    EO_SYSTEM_PROMPT
  end

  it 'does not embed the input artifacts content in the system prompt' do
    expect(
      system_prompt(
        role: 'Test Agent Role',
        input_artifacts_contracts: { requirements: 'The features specifications' },
        input_artifacts: { requirements: 'Feature specifications content' },
        rendered_instructions: ['Instruction 1', 'Instruction 2']
      )
    ).to eq <<~EO_SYSTEM_PROMPT.strip
      # Role

      Test Agent Role

      # Instructions

      Instruction 1

      Instruction 2

      # Input artifacts' concept and usage

      - Artifacts are documents that you can get as input.
      - Each artifact is identified by a name, like `ARTIFACT_PLAN`.
      - You must consider all artifacts given in the "Input artifacts" section of the user prompt.
      - All artifacts presented in the "Input artifacts" section of the user prompt provide their content in an in-line JSON document.
      - The content of input artifact `ARTIFACT_REQUIREMENTS` describes this: The features specifications
      - The input artifact `ARTIFACT_REQUIREMENTS` is expected to be in the user prompt.
      - The input artifact `ARTIFACT_REQUIREMENTS` artifact content is embedded directly in the user prompt as in-line JSON. It is NOT a file. Do NOT try to open it as a file.
    EO_SYSTEM_PROMPT
  end

  describe 'with input artifacts contracts' do
    it 'includes input artifacts concept section with required artifacts' do
      expect(
        system_prompt(
          input_artifacts_contracts: {
            plan: 'The plan document',
            data: { description: 'The data content', optional: false }
          }
        )
      ).to eq <<~EO_SYSTEM_PROMPT.strip
        # Role

        Test Agent Role

        # Instructions

        Instruction 1

        Instruction 2

        # Input artifacts' concept and usage

        - Artifacts are documents that you can get as input.
        - Each artifact is identified by a name, like `ARTIFACT_PLAN`.
        - You must consider all artifacts given in the "Input artifacts" section of the user prompt.
        - All artifacts presented in the "Input artifacts" section of the user prompt provide their content in an in-line JSON document.
        - The content of input artifact `ARTIFACT_PLAN` describes this: The plan document
        - The input artifact `ARTIFACT_PLAN` is expected to be in the user prompt.
        - The input artifact `ARTIFACT_PLAN` artifact content is embedded directly in the user prompt as in-line JSON. It is NOT a file. Do NOT try to open it as a file.
        - The content of input artifact `ARTIFACT_DATA` describes this: The data content
        - The input artifact `ARTIFACT_DATA` is expected to be in the user prompt.
        - The input artifact `ARTIFACT_DATA` artifact content is embedded directly in the user prompt as in-line JSON. It is NOT a file. Do NOT try to open it as a file.
      EO_SYSTEM_PROMPT
    end

    it 'documents optional input artifacts differently from required ones' do
      expect(
        system_prompt(
          input_artifacts_contracts: {
            required_doc: 'A required document',
            optional_doc: { description: 'An optional document', optional: true }
          }
        )
      ).to eq <<~EO_SYSTEM_PROMPT.strip
        # Role

        Test Agent Role

        # Instructions

        Instruction 1

        Instruction 2

        # Input artifacts' concept and usage

        - Artifacts are documents that you can get as input.
        - Each artifact is identified by a name, like `ARTIFACT_PLAN`.
        - You must consider all artifacts given in the "Input artifacts" section of the user prompt.
        - All artifacts presented in the "Input artifacts" section of the user prompt provide their content in an in-line JSON document.
        - The content of input artifact `ARTIFACT_REQUIRED_DOC` describes this: A required document
        - The input artifact `ARTIFACT_REQUIRED_DOC` is expected to be in the user prompt.
        - The input artifact `ARTIFACT_REQUIRED_DOC` artifact content is embedded directly in the user prompt as in-line JSON. It is NOT a file. Do NOT try to open it as a file.
        - The content of input artifact `ARTIFACT_OPTIONAL_DOC` describes this: An optional document
        - The input artifact `ARTIFACT_OPTIONAL_DOC` is optional and may not be given to you.
        - The input artifact `ARTIFACT_OPTIONAL_DOC` artifact content is embedded directly in the user prompt as in-line JSON. It is NOT a file. Do NOT try to open it as a file.
      EO_SYSTEM_PROMPT
    end

    it 'filters out the user_message artifact from input artifacts documentation' do
      expect(
        system_prompt(
          input_artifacts_contracts: {
            user_message: 'User prompt',
            plan: 'The plan document'
          }
        )
      ).to eq <<~EO_SYSTEM_PROMPT.strip
        # Role

        Test Agent Role

        # Instructions

        Instruction 1

        Instruction 2

        # Input artifacts' concept and usage

        - Artifacts are documents that you can get as input.
        - Each artifact is identified by a name, like `ARTIFACT_PLAN`.
        - You must consider all artifacts given in the "Input artifacts" section of the user prompt.
        - All artifacts presented in the "Input artifacts" section of the user prompt provide their content in an in-line JSON document.
        - The content of input artifact `ARTIFACT_PLAN` describes this: The plan document
        - The input artifact `ARTIFACT_PLAN` is expected to be in the user prompt.
        - The input artifact `ARTIFACT_PLAN` artifact content is embedded directly in the user prompt as in-line JSON. It is NOT a file. Do NOT try to open it as a file.
      EO_SYSTEM_PROMPT
    end

    it 'combines input artifacts with objective and constraints' do
      expect(
        system_prompt(
          input_artifacts_contracts: {
            plan: 'The plan'
          },
          objective: 'Produce analysis report',
          constraints: 'Limit to 3 pages'
        )
      ).to eq <<~EO_SYSTEM_PROMPT.strip
        # Role

        Test Agent Role

        # Objective

        Produce analysis report

        # Instructions

        Instruction 1

        Instruction 2

        # Constraints

        Limit to 3 pages

        # Input artifacts' concept and usage

        - Artifacts are documents that you can get as input.
        - Each artifact is identified by a name, like `ARTIFACT_PLAN`.
        - You must consider all artifacts given in the "Input artifacts" section of the user prompt.
        - All artifacts presented in the "Input artifacts" section of the user prompt provide their content in an in-line JSON document.
        - The content of input artifact `ARTIFACT_PLAN` describes this: The plan
        - The input artifact `ARTIFACT_PLAN` is expected to be in the user prompt.
        - The input artifact `ARTIFACT_PLAN` artifact content is embedded directly in the user prompt as in-line JSON. It is NOT a file. Do NOT try to open it as a file.
      EO_SYSTEM_PROMPT
    end
  end

  describe 'with output artifacts' do
    it 'includes output artifacts concept section' do
      expect(
        system_prompt(
          output_artifacts_contracts: {
            report: 'The final report',
            summary: 'Executive summary'
          }
        )
      ).to eq <<~EO_SYSTEM_PROMPT.strip
        # Role

        Test Agent Role

        # Instructions

        Instruction 1

        Instruction 2

        # Output artifacts' concept and usage

        - The user will ask you to provide some artifacts as output.
        - You must always return the required artifact as a JSON document in your response, with its name in the JSON header, like this:
          ```json artifact=ARTIFACT_NAME
          {artifact_content}
          ```
        - Do not create files for output artifacts: always give them inside embedded JSON in your last response.
        - Always return output artifacts that the user is asking you to provide.
        - You can return several output artifacts in your final response if needed.
        - The content of output artifact `ARTIFACT_REPORT` should describe this: The final report
        - The output artifact `ARTIFACT_REPORT` should be given in a block like this:
          ```json artifact=ARTIFACT_REPORT
          {artifact_content}
          ```
        - The content of output artifact `ARTIFACT_SUMMARY` should describe this: Executive summary
        - The output artifact `ARTIFACT_SUMMARY` should be given in a block like this:
          ```json artifact=ARTIFACT_SUMMARY
          {artifact_content}
          ```
      EO_SYSTEM_PROMPT
    end

    it 'combines output artifacts with objective and constraints' do
      expect(
        system_prompt(
          output_artifacts_contracts: {
            report: 'The final report'
          },
          objective: 'Generate monthly report',
          constraints: 'Use formal language'
        )
      ).to eq <<~EO_SYSTEM_PROMPT.strip
        # Role

        Test Agent Role

        # Objective

        Generate monthly report

        # Instructions

        Instruction 1

        Instruction 2

        # Constraints

        Use formal language

        # Output artifacts' concept and usage

        - The user will ask you to provide some artifacts as output.
        - You must always return the required artifact as a JSON document in your response, with its name in the JSON header, like this:
          ```json artifact=ARTIFACT_NAME
          {artifact_content}
          ```
        - Do not create files for output artifacts: always give them inside embedded JSON in your last response.
        - Always return output artifacts that the user is asking you to provide.
        - You can return several output artifacts in your final response if needed.
        - The content of output artifact `ARTIFACT_REPORT` should describe this: The final report
        - The output artifact `ARTIFACT_REPORT` should be given in a block like this:
          ```json artifact=ARTIFACT_REPORT
          {artifact_content}
          ```
      EO_SYSTEM_PROMPT
    end
  end

  describe 'with both input and output artifacts' do
    it 'includes both input and output artifacts concept sections' do
      expect(
        system_prompt(
          input_artifacts_contracts: {
            plan: 'The plan'
          },
          output_artifacts_contracts: {
            report: 'The final report'
          }
        )
      ).to eq <<~EO_SYSTEM_PROMPT.strip
        # Role

        Test Agent Role

        # Instructions

        Instruction 1

        Instruction 2

        # Input artifacts' concept and usage

        - Artifacts are documents that you can get as input.
        - Each artifact is identified by a name, like `ARTIFACT_PLAN`.
        - You must consider all artifacts given in the "Input artifacts" section of the user prompt.
        - All artifacts presented in the "Input artifacts" section of the user prompt provide their content in an in-line JSON document.
        - The content of input artifact `ARTIFACT_PLAN` describes this: The plan
        - The input artifact `ARTIFACT_PLAN` is expected to be in the user prompt.
        - The input artifact `ARTIFACT_PLAN` artifact content is embedded directly in the user prompt as in-line JSON. It is NOT a file. Do NOT try to open it as a file.

        # Output artifacts' concept and usage

        - The user will ask you to provide some artifacts as output.
        - You must always return the required artifact as a JSON document in your response, with its name in the JSON header, like this:
          ```json artifact=ARTIFACT_NAME
          {artifact_content}
          ```
        - Do not create files for output artifacts: always give them inside embedded JSON in your last response.
        - Always return output artifacts that the user is asking you to provide.
        - You can return several output artifacts in your final response if needed.
        - The content of output artifact `ARTIFACT_REPORT` should describe this: The final report
        - The output artifact `ARTIFACT_REPORT` should be given in a block like this:
          ```json artifact=ARTIFACT_REPORT
          {artifact_content}
          ```
      EO_SYSTEM_PROMPT
    end
  end
end
