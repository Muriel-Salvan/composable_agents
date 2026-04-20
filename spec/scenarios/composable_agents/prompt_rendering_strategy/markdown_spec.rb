describe ComposableAgents::PromptRenderingStrategy::Markdown do
  # Instantiate an agent for this strategy
  #
  # @param args [Array] Args to be give the agent's constructor
  # @param kwargs [Hash] Keyword args to be give the agent's constructor
  # @return [ComposableAgents::PromptDrivenAgent] Agent to be tested
  def agent(*args, **kwargs)
    Class.new(ComposableAgents::PromptDrivenAgent) do
      include ComposableAgents::PromptRenderingStrategy::Markdown
    end.new(*args, **kwargs)
  end

  describe '#render_instruction_text' do
    it 'returns the instruction' do
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
    it 'renders an ordered list with correct numbering' do
      expect(
        agent.render_instruction_ordered_list(['First step', 'Second step', 'Third step'])
      ).to eq <<~EO_RENDERED_INSTRUCTION.strip
        # 1. First step

        # 2. Second step

        # 3. Third step

      EO_RENDERED_INSTRUCTION
    end

    it 'handles single item list correctly' do
      expect(agent.render_instruction_ordered_list(['Only one step'])).to eq('# 1. Only one step')
    end

    it 'handles empty list correctly' do
      expect(agent.render_instruction_ordered_list([])).to eq('')
    end
  end

  describe '#render_system_prompt' do
    # Render the system prompt for a given agent's constructor parameters
    #
    # @param kwargs [Hash] The constructor parameters of the agent
    # @return [String] The rendered system prompt
    def system_prompt(**kwargs)
      agent(role: 'Test Agent Role', **kwargs).render_system_prompt(['Instruction 1', 'Instruction 2'])
    end

    it 'includes role section always' do
      expect(system_prompt).to eq <<~EO_SYSTEM_PROMPT.strip
        # Role

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

    it 'does not use the input artifacts' do
      expect(
        agent(role: 'Test Agent Role').render_system_prompt(['Instruction 1', 'Instruction 2'], input_artifacts: { document: 'Description' })
      ).to eq <<~EO_SYSTEM_PROMPT.strip
        # Role

        Test Agent Role

        # Instructions

        Instruction 1

        Instruction 2
      EO_SYSTEM_PROMPT
    end
  end

  describe '#render_user_prompt' do
    it 'returns the user message unchanged' do
      expect(agent.render_user_prompt('Hello, I need assistance')).to eq('Hello, I need assistance')
    end

    it 'handles empty message correctly' do
      expect(agent.render_user_prompt('')).to eq('')
    end

    it 'does not use input artifacts' do
      expect(agent.render_user_prompt('Hello, I need assistance', input_artifacts: { key: 'value' })).to eq('Hello, I need assistance')
    end
  end

  describe '#render_missing_output_user_prompt' do
    it 'renders missing artifacts as bullet points' do
      expect(
        agent.render_missing_output_user_prompt(
          report: 'Final report document',
          summary: 'Executive summary',
          logs: 'Execution logs'
        )
      ).to eq <<~EO_PROMPT
        Some artifacts are missing:
        - You must create an artifact named `report`: Final report document
        - You must create an artifact named `summary`: Executive summary
        - You must create an artifact named `logs`: Execution logs
      EO_PROMPT
    end

    it 'handles single missing artifact correctly' do
      expect(agent.render_missing_output_user_prompt(result: 'Calculation result')).to eq <<~EO_PROMPT
        Some artifacts are missing:
        - You must create an artifact named `result`: Calculation result
      EO_PROMPT
    end
  end
end
