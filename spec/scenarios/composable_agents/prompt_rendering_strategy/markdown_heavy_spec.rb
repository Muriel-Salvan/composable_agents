require 'json'

describe ComposableAgents::PromptRenderingStrategy::MarkdownHeavy do
  # Instantiate an agent for this strategy, with ArtifactContract mixin prepended
  #
  # @param args [Array] Args to be given to the agent's constructor
  # @param context [Object] Context to be given to the agent
  # @param kwargs [Hash] Keyword args to be given to the agent's constructor
  # @return [ComposableAgents::PromptDrivenAgent] Agent to be tested
  def agent(*args, context: {}, **kwargs)
    Class.new(ComposableAgents::PromptDrivenAgent) do
      prepend ComposableAgents::Mixins::ArtifactContract
      include ComposableAgents::PromptRenderingStrategy::MarkdownHeavy

      # Constructor
      #
      # @param args [Array] Args to be given to the agent's constructor
      # @param context [Object] Context to be given to the agent
      # @param kwargs [Hash] Keyword args to be given to the agent's constructor
      def initialize(*args, context:, **kwargs)
        super(*args, **kwargs)
        @context = context
      end
    end.new(*args, context:, **kwargs)
  end

  describe '#render_instruction_text' do
    it 'returns the instruction unchanged' do
      expect(agent.render_instruction_text('This is a test instruction')).to eq('This is a test instruction')
    end

    it 'handles empty string correctly' do
      expect(agent.render_instruction_text('')).to eq('')
    end

    it 'handles multi-line text correctly' do
      expect(agent.render_instruction_text("Line 1\nLine 2\nLine 3")).to eq("Line 1\nLine 2\nLine 3")
    end
  end

  describe '#render_instruction_ordered_list' do
    it 'renders an ordered list with mandatory checklist framing' do
      expect(
        agent(name: 'TestExecutor').render_instruction_ordered_list(['First step', 'Second step', 'Third step'])
      ).to eq <<~EO_RENDERED_INSTRUCTION
        Always follow all those sequential steps.

        # 1. Create the TestExecutor Execution Checklist (MANDATORY)

        - Before executing anything, create a checklist named TestExecutor Execution Checklist with all steps of these instructions.
        - Do not create files to track this checklist: keep it in your memory.
        - The TestExecutor Execution Checklist must include all numbered steps explicitly.
        - After completing each step of these instructions, mark the item in the TestExecutor Execution Checklist as completed.
        - Do not skip any item.
        - If an item cannot be executed, explicitly explain why.
        - Never mark the task as completed while any item from the TestExecutor Execution Checklist remains open.

        # 2. First step

        # 3. Second step

        # 4. Third step

        # 5. Final Verification (MANDATORY)

        Before declaring the task complete:

        - Re-list all numbered steps from the TestExecutor Execution Checklist.
        - Confirm each one was executed.
        - If any step was not executed, execute it now.
      EO_RENDERED_INSTRUCTION
    end

    it 'renders an ordered list with multiline steps and sub-sections' do
      test_agent = agent(name: 'TestExecutor')
      expect(
        test_agent.render_instruction_ordered_list(
          [
            <<~EO_STEP,
              First step

              Sub instruction 1
            EO_STEP
            <<~EO_STEP,
              Second step

              ### Sub section 2

              Sub instruction 2
            EO_STEP
            <<~EO_STEP
              Third step

              # Sub section 3

              Sub instruction 3
            EO_STEP
          ]
        )
      ).to eq <<~EO_RENDERED_INSTRUCTION
        Always follow all those sequential steps.

        # 1. Create the TestExecutor Execution Checklist (MANDATORY)

        - Before executing anything, create a checklist named TestExecutor Execution Checklist with all steps of these instructions.
        - Do not create files to track this checklist: keep it in your memory.
        - The TestExecutor Execution Checklist must include all numbered steps explicitly.
        - After completing each step of these instructions, mark the item in the TestExecutor Execution Checklist as completed.
        - Do not skip any item.
        - If an item cannot be executed, explicitly explain why.
        - Never mark the task as completed while any item from the TestExecutor Execution Checklist remains open.

        # 2. First step

        Sub instruction 1

        # 3. Second step

        ## Sub section 2

        Sub instruction 2

        # 4. Third step

        ## Sub section 3

        Sub instruction 3

        # 5. Final Verification (MANDATORY)

        Before declaring the task complete:

        - Re-list all numbered steps from the TestExecutor Execution Checklist.
        - Confirm each one was executed.
        - If any step was not executed, execute it now.
      EO_RENDERED_INSTRUCTION
    end

    it 'handles single item list with mandatory checklist framing' do
      test_agent = agent(name: 'SoloAgent')
      expect(
        test_agent.render_instruction_ordered_list(['Only one step'])
      ).to eq <<~EO_RENDERED_INSTRUCTION
        Always follow all those sequential steps.

        # 1. Create the SoloAgent Execution Checklist (MANDATORY)

        - Before executing anything, create a checklist named SoloAgent Execution Checklist with all steps of these instructions.
        - Do not create files to track this checklist: keep it in your memory.
        - The SoloAgent Execution Checklist must include all numbered steps explicitly.
        - After completing each step of these instructions, mark the item in the SoloAgent Execution Checklist as completed.
        - Do not skip any item.
        - If an item cannot be executed, explicitly explain why.
        - Never mark the task as completed while any item from the SoloAgent Execution Checklist remains open.

        # 2. Only one step

        # 3. Final Verification (MANDATORY)

        Before declaring the task complete:

        - Re-list all numbered steps from the SoloAgent Execution Checklist.
        - Confirm each one was executed.
        - If any step was not executed, execute it now.
      EO_RENDERED_INSTRUCTION
    end

    it 'handles empty list with only checklist framing' do
      expect(agent.render_instruction_ordered_list([])).to eq ''
    end
  end

  describe '#render_system_prompt' do
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
      agent(input_artifacts: input_artifacts_contracts, role:, **kwargs).render_system_prompt(rendered_instructions, input_artifacts:)
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

    context 'with input artifacts contracts' do
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

    context 'with output artifacts contracts' do
      it 'includes output artifacts concept section' do
        expect(
          system_prompt(
            output_artifacts: {
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
            output_artifacts: {
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

    context 'with both input and output artifacts contracts' do
      it 'includes both input and output artifacts concept sections' do
        expect(
          system_prompt(
            input_artifacts_contracts: {
              plan: 'The plan'
            },
            output_artifacts: {
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

  describe '#render_user_prompt' do
    it 'returns only the user message section when context and input artifacts are empty' do
      expect(agent.render_user_prompt('Hello, I need assistance')).to eq <<~EO_PROMPT.strip
        # User instructions

        Hello, I need assistance
      EO_PROMPT
    end

    it 'handles empty user message with no context or artifacts' do
      expect(agent.render_user_prompt('')).to eq('')
    end

    it 'includes previous sessions context when @context is set' do
      expect(
        agent(context: { 'previous_task' => 'analyzed data', 'findings' => %w[item1 item2] })
          .render_user_prompt('Continue with the task')
      ).to eq <<~EO_PROMPT.strip
        # Previous sessions context

        Here is the conversation from a previous session for context:

        ```json
        {"previous_task":"analyzed data","findings":["item1","item2"]}
        ```

        Continue with the task, building on the work from the session above.

        # User instructions

        Continue with the task
      EO_PROMPT
    end

    it 'includes input artifacts section when input artifacts are provided' do
      expect(
        agent.render_user_prompt(
          'Process these documents',
          input_artifacts: {
            plan: 'Build a house',
            budget: { amount: 50_000, currency: 'EUR' }
          }
        )
      ).to eq <<~EO_PROMPT.strip
        # Input artifacts

        ## `ARTIFACT_PLAN`

        ```json artifact=ARTIFACT_PLAN
        "Build a house"
        ```

        ## `ARTIFACT_BUDGET`

        ```json artifact=ARTIFACT_BUDGET
        {"amount":50000,"currency":"EUR"}
        ```

        # User instructions

        Process these documents
      EO_PROMPT
    end

    it 'includes both context and input artifacts sections when both are present' do
      expect(
        agent(context: { 'session' => 1, 'progress' => '50%' }).render_user_prompt(
          'Please finish the task',
          input_artifacts: {
            plan: 'Complete the report',
            draft: 'Partial draft content'
          }
        )
      ).to eq <<~EO_PROMPT.strip
        # Previous sessions context

        Here is the conversation from a previous session for context:

        ```json
        {"session":1,"progress":"50%"}
        ```

        Continue with the task, building on the work from the session above.

        # Input artifacts

        ## `ARTIFACT_PLAN`

        ```json artifact=ARTIFACT_PLAN
        "Complete the report"
        ```

        ## `ARTIFACT_DRAFT`

        ```json artifact=ARTIFACT_DRAFT
        "Partial draft content"
        ```

        # User instructions

        Please finish the task
      EO_PROMPT
    end

    it 'handles input artifacts with empty user message' do
      expect(
        agent.render_user_prompt(
          '',
          input_artifacts: {
            plan: 'Just the plan'
          }
        )
      ).to eq <<~EO_PROMPT.strip
        # Input artifacts

        ## `ARTIFACT_PLAN`

        ```json artifact=ARTIFACT_PLAN
        "Just the plan"
        ```
      EO_PROMPT
    end

    it 'handles context without user message' do
      expect(agent(context: { 'id' => 42 }).render_user_prompt('')).to eq <<~EO_PROMPT.strip
        # Previous sessions context

        Here is the conversation from a previous session for context:

        ```json
        {"id":42}
        ```

        Continue with the task, building on the work from the session above.
      EO_PROMPT
    end

    it 'handles empty context hash correctly with artifacts' do
      expect(
        agent.render_user_prompt(
          'Simple message',
          input_artifacts: {
            doc: 'Some content'
          }
        )
      ).to eq <<~EO_PROMPT.strip
        # Input artifacts

        ## `ARTIFACT_DOC`

        ```json artifact=ARTIFACT_DOC
        "Some content"
        ```

        # User instructions

        Simple message
      EO_PROMPT
    end
  end

  describe '#missing_output_user_prompt' do
    it 'prompts for missing artifacts' do
      expect(
        agent.missing_output_user_prompt(
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

        ```json artifact=ARTIFACT_REPORT
        {ARTIFACT_REPORT artifact content}
        ```

        ```json artifact=ARTIFACT_SUMMARY
        {ARTIFACT_SUMMARY artifact content}
        ```

        ```json artifact=ARTIFACT_LOGS
        {ARTIFACT_LOGS artifact content}
        ```

        - You must return all those artifacts in your next response (MANDATORY).
      EO_PROMPT
    end

    it 'handles single missing artifact correctly' do
      expect(
        agent.missing_output_user_prompt(
          result: { description: 'Calculation result' }
        )
      ).to eq <<~EO_PROMPT
        The following output artifacts are missing from your previous responses:
        - `ARTIFACT_RESULT`: Calculation result

        You must provide each one of them in your next response using embedded JSON blocks like this:

        ```json artifact=ARTIFACT_RESULT
        {ARTIFACT_RESULT artifact content}
        ```

        - You must return all those artifacts in your next response (MANDATORY).
      EO_PROMPT
    end
  end

  describe '.assistant_artifact_name' do
    it 'converts a symbol artifact name to an uppercase string with ARTIFACT_ prefix' do
      expect(described_class.assistant_artifact_name(:plan)).to eq('ARTIFACT_PLAN')
    end

    it 'converts a snake_case name correctly' do
      expect(described_class.assistant_artifact_name(:monthly_report)).to eq('ARTIFACT_MONTHLY_REPORT')
    end
  end
end
