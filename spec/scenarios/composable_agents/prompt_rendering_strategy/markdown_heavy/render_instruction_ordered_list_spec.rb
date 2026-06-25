describe ComposableAgents::PromptRenderingStrategy::MarkdownHeavy, '#render_instruction_ordered_list' do
  it 'renders an ordered list with mandatory checklist framing' do
    expect(
      agent_for_markdown_heavy(name: 'TestExecutor').render_instruction_ordered_list(['First step', 'Second step', 'Third step'])
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
    test_agent = agent_for_markdown_heavy(name: 'TestExecutor')
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
    test_agent = agent_for_markdown_heavy(name: 'SoloAgent')
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
    expect(agent_for_markdown_heavy.render_instruction_ordered_list([])).to eq ''
  end

  it 'uses default "Agent" name when agent has no name' do
    expect(
      agent_for_markdown_heavy.render_instruction_ordered_list(['First step', 'Second step'])
    ).to eq <<~EO_RENDERED_INSTRUCTION
      Always follow all those sequential steps.

      # 1. Create the Agent Execution Checklist (MANDATORY)

      - Before executing anything, create a checklist named Agent Execution Checklist with all steps of these instructions.
      - Do not create files to track this checklist: keep it in your memory.
      - The Agent Execution Checklist must include all numbered steps explicitly.
      - After completing each step of these instructions, mark the item in the Agent Execution Checklist as completed.
      - Do not skip any item.
      - If an item cannot be executed, explicitly explain why.
      - Never mark the task as completed while any item from the Agent Execution Checklist remains open.

      # 2. First step

      # 3. Second step

      # 4. Final Verification (MANDATORY)

      Before declaring the task complete:

      - Re-list all numbered steps from the Agent Execution Checklist.
      - Confirm each one was executed.
      - If any step was not executed, execute it now.
    EO_RENDERED_INSTRUCTION
  end
end
