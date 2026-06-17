describe ComposableAgents::PromptRenderingStrategy::Markdown, '#render_system_prompt' do
  # Render the system prompt for a given agent's constructor parameters
  #
  # @param rendered_instructions [Array<String>] The rendered instructions
  # @param role [String] the role to give the agent
  # @param kwargs [Hash] The constructor parameters of the agent
  # @return [String] The rendered system prompt
  def system_prompt(
    rendered_instructions: "Instruction 1\n\nInstruction 2",
    **kwargs
  )
    agent_for_markdown(**kwargs).render_system_prompt(rendered_instructions)
  end

  it 'includes role section if present' do
    expect(system_prompt(role: 'Test Agent Role')).to eq <<~EO_SYSTEM_PROMPT.strip
      # Role

      Test Agent Role

      # Instructions

      Instruction 1

      Instruction 2
    EO_SYSTEM_PROMPT
  end

  it 'omits role section when role is empty' do
    expect(
      system_prompt(role: '')
    ).to eq <<~EO_SYSTEM_PROMPT.strip
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

  it 'levels small headers in roles properly' do
    expect(
      system_prompt(
        role: <<~EO_ROLE
          #### Role Header 1

          ##### 1. Role Header 1.1

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

  it 'levels big headers in instructions properly' do
    expect(
      system_prompt(
        rendered_instructions: <<~EO_INSTRUCTIONS
          # Header 1

          ## 1. Header 1.1

          ## 2. Header 1.2
        EO_INSTRUCTIONS
      )
    ).to eq <<~EO_SYSTEM_PROMPT.strip
      # Instructions

      ## Header 1

      ### 1. Header 1.1

      ### 2. Header 1.2
    EO_SYSTEM_PROMPT
  end

  it 'levels small headers in instructions properly' do
    expect(
      system_prompt(
        rendered_instructions: <<~EO_INSTRUCTIONS
          ### Header 1

          #### Header 1.1

          ##### Header 1.1.1
        EO_INSTRUCTIONS
      )
    ).to eq <<~EO_SYSTEM_PROMPT.strip
      # Instructions

      ## Header 1

      ### Header 1.1

      #### Header 1.1.1
    EO_SYSTEM_PROMPT
  end

  it 'includes objective section when objective is present' do
    expect(
      system_prompt(objective: 'Complete the assigned task')
    ).to eq <<~EO_SYSTEM_PROMPT.strip
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
      # Instructions

      Instruction 1

      Instruction 2
    EO_SYSTEM_PROMPT
  end

  it 'levels big headers in objective properly' do
    expect(
      system_prompt(
        objective: <<~EO_OBJECTIVE
          # Objective Header 1

          ## 1. Objective Header 1.1

          Complete the assigned task
        EO_OBJECTIVE
      )
    ).to eq <<~EO_SYSTEM_PROMPT.strip
      # Objective

      ## Objective Header 1

      ### 1. Objective Header 1.1

      Complete the assigned task

      # Instructions

      Instruction 1

      Instruction 2
    EO_SYSTEM_PROMPT
  end

  it 'levels small headers in objective properly' do
    expect(
      system_prompt(
        objective: <<~EO_OBJECTIVE
          #### Objective Header 1

          ##### 1. Objective Header 1.1

          Complete the assigned task
        EO_OBJECTIVE
      )
    ).to eq <<~EO_SYSTEM_PROMPT.strip
      # Objective

      ## Objective Header 1

      ### 1. Objective Header 1.1

      Complete the assigned task

      # Instructions

      Instruction 1

      Instruction 2
    EO_SYSTEM_PROMPT
  end

  it 'includes constraints section when constraints are present' do
    expect(
      system_prompt(constraints: 'Do not exceed token limits')
    ).to eq <<~EO_SYSTEM_PROMPT.strip
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
      # Instructions

      Instruction 1

      Instruction 2
    EO_SYSTEM_PROMPT
  end

  it 'levels big headers in constraints properly' do
    expect(
      system_prompt(
        constraints: <<~EO_CONSTRAINTS
          # Constraints Header 1

          ## 1. Constraints Header 1.1

          Do not exceed token limits
        EO_CONSTRAINTS
      )
    ).to eq <<~EO_SYSTEM_PROMPT.strip
      # Instructions

      Instruction 1

      Instruction 2

      # Constraints

      ## Constraints Header 1

      ### 1. Constraints Header 1.1

      Do not exceed token limits
    EO_SYSTEM_PROMPT
  end

  it 'levels small headers in constraints properly' do
    expect(
      system_prompt(
        constraints: <<~EO_CONSTRAINTS
          #### Constraints Header 1

          ##### 1. Constraints Header 1.1

          Do not exceed token limits
        EO_CONSTRAINTS
      )
    ).to eq <<~EO_SYSTEM_PROMPT.strip
      # Instructions

      Instruction 1

      Instruction 2

      # Constraints

      ## Constraints Header 1

      ### 1. Constraints Header 1.1

      Do not exceed token limits
    EO_SYSTEM_PROMPT
  end

  it 'does not use the input artifacts' do
    expect(
      agent_for_markdown.render_system_prompt("Instruction 1\n\nInstruction 2", input_artifacts: { document: 'Description' })
    ).to eq <<~EO_SYSTEM_PROMPT.strip
      # Instructions

      Instruction 1

      Instruction 2
    EO_SYSTEM_PROMPT
  end
end
