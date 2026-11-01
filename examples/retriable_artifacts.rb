require 'composable_agents'
require 'agents'

# Example demonstrating automatic retry of output artifacts using the RetriableArtifacts mixin.
#
# The RetriableArtifacts mixin automatically re-runs a PromptDrivenAgent when output artifacts
# declared in contracts are missing or in error. It requires both ArtifactContract and Retriable
# mixins to be prepended, and must be prepended on an agent descending from PromptDrivenAgent.
#
# This example uses the ai-agents LLM backend. Set the OPENROUTER_API_KEY environment variable
# before running.

# Configure the ai-agents backend
Agents.configure do |config|
  config.openrouter_api_key = ENV.fetch('OPENROUTER_API_KEY', nil)
end

# An analysis agent that produces a result and logs.
# If either artifact is missing after a run, RetriableArtifacts automatically
# re-runs the agent with a prompt asking for the missing artifacts.
class AnalysisAgent < ComposableAgents::AiAgents::Agent
  prepend ComposableAgents::Mixins::ArtifactContract
  prepend ComposableAgents::Mixins::Retriable
  prepend ComposableAgents::Mixins::RetriableArtifacts

  def initialize
    super(
      role: 'You are a data analyst',
      objective: 'Analyze the input data and produce a result with execution logs',
      system_instructions: <<~EO_INSTRUCTIONS,
        Analyze the data provided in the `input_data` artifact.
        Create an artifact named `result` with your analysis findings as text.
        Create an artifact named `logs` with a summary of the steps you performed.
      EO_INSTRUCTIONS
      model: 'arcee-ai/trinity-large-thinking:free'
    )
  end

  def output_artifacts_contracts
    {
      result: 'The analysis findings',
      logs: 'A summary of the analysis steps performed'
    }
  end
end

agent = AnalysisAgent.new(artifacts_errors_max_retries: 3)
outputs = agent.run(input_data: 'Q1 sales: $1000, Q2 sales: $1500, Q3 sales: $1200')

puts "Result: #{outputs[:result]}"
puts "Logs: #{outputs[:logs]}"
