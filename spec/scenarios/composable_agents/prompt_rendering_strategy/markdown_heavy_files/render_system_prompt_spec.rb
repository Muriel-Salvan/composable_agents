require 'tmpdir'

describe ComposableAgents::PromptRenderingStrategy::MarkdownHeavyFiles, '#render_system_prompt' do
  attr_reader :composable_agents_dir

  around do |example|
    Dir.mktmpdir do |dir|
      @composable_agents_dir = dir
      example.run
    end
  end

  # Render the system prompt for a given agent's constructor parameters.
  #
  # @param rendered_instructions [String, nil] The rendered system instructions, or nil if none
  # @param input_artifacts_contracts [Hash{Symbol => Object}, nil] Hash of input artifact names and their contracts, or nil if none.
  # @param output_artifacts_contracts [Hash{Symbol => Object}, nil] Hash of output artifact names and their contracts, or nil if none.
  # @param kwargs [Hash] The constructor parameters of the agent
  # @return [String] The rendered system prompt
  def system_prompt(
    rendered_instructions: "Instruction 1\n\nInstruction 2",
    input_artifacts_contracts: nil,
    output_artifacts_contracts: nil,
    **kwargs
  )
    agent = agent_for_markdown_heavy_files(
      composable_agents_dir:,
      input_artifacts_contracts:,
      output_artifacts_contracts:,
      **kwargs
    )
    agent.render_system_prompt(rendered_instructions)
  end

  let(:plan_path) { File.join(composable_agents_dir, 'artifacts', 'input', 'plan.json') }
  let(:report_path) { File.join(composable_agents_dir, 'artifacts', 'output', 'report.txt') }

  it 'includes instructions section without artifacts intro if there are no artifacts' do
    expect(system_prompt).to eq <<~EO_SYSTEM_PROMPT.strip
      # Instructions

      Instruction 1

      Instruction 2
    EO_SYSTEM_PROMPT
  end

  it 'describes input artifacts as persisted files' do
    expect(system_prompt(input_artifacts_contracts: { plan: 'The plan' })).to eq <<~EO_SYSTEM_PROMPT.strip
      # Instructions

      Instruction 1

      Instruction 2

      # Input artifacts' concept and usage

      - Artifacts are documents that you can get as input.
      - Each input artifact is persisted as a file on disk, identified by its absolute path, like `#{plan_path}`.
      - You must consider all artifacts given in the "Input artifacts" section of the user prompt.
      - The "Input artifacts" section of the user prompt gives you the absolute path of each input artifact file.
      - Open and read the file at the given absolute path whenever you need the corresponding input artifact content.
      - The file extension indicates the artifact content type: `.json` for JSON, `.md` for Markdown, `.txt` for raw text.
      - The content of input artifact `#{plan_path}` describes this: The plan
      - The input artifact `#{plan_path}` is expected in the user prompt.
    EO_SYSTEM_PROMPT
  end

  it 'describes optional input artifacts as such' do
    expect(
      system_prompt(input_artifacts_contracts: { plan: { description: 'The plan', optional: true } })
    ).to eq <<~EO_SYSTEM_PROMPT.strip
      # Instructions

      Instruction 1

      Instruction 2

      # Input artifacts' concept and usage

      - Artifacts are documents that you can get as input.
      - Each input artifact is persisted as a file on disk, identified by its absolute path, like `#{plan_path}`.
      - You must consider all artifacts given in the "Input artifacts" section of the user prompt.
      - The "Input artifacts" section of the user prompt gives you the absolute path of each input artifact file.
      - Open and read the file at the given absolute path whenever you need the corresponding input artifact content.
      - The file extension indicates the artifact content type: `.json` for JSON, `.md` for Markdown, `.txt` for raw text.
      - The content of input artifact `#{plan_path}` describes this: The plan
      - The input artifact `#{plan_path}` is optional and may not be given to you.
    EO_SYSTEM_PROMPT
  end

  it 'describes output artifacts as files to write' do
    expect(
      system_prompt(output_artifacts_contracts: { report: { description: 'The final report', type: :text } })
    ).to eq <<~EO_SYSTEM_PROMPT.strip
      # Instructions

      Instruction 1

      Instruction 2

      # Output artifacts' concept and usage

      - The user will ask you to provide some artifacts as output.
      - Each output artifact must be written to a file on disk, at the exact absolute path given in this system prompt.
      - Do NOT return output artifacts inline in your response: always write each one of them to its expected file path.
      - Always return output artifacts that the user is asking you to provide.
      - You can return several output artifacts in your responses if needed.

      Following sections enumerate all expected output artifacts.

      ## Output artifact `#{report_path}`

      - The content of output artifact `#{report_path}` should describe this: The final report
      - The output artifact `#{report_path}` content format should be text
      - Write the output artifact `#{report_path}` to this exact absolute path. The file extension indicates the expected content type.
    EO_SYSTEM_PROMPT
  end
end
