require 'composable_agents'

# Example of output:
# 1. Ask the preferences agent to gather holidays preferences...
# What kind of holidays are you looking for?
# Seaside in France
# 2. Ask the itinerary agent to get a list of cities for those preferences...
# 3. Ask the budget agent about money for the given itinerary...
# Budget for the cities ["Nice", "Cannes", "Marseille", "Biarritz", "Saint-Tropez", "La Rochelle", "Deauville", "Antibes", "Saint-Malo", "Ajaccio"] is $10000

raise 'Set the Cline API key in the CLINE_API_KEY env variable' unless ENV.key?('CLINE_API_KEY')

# Define agents
preferences_agent = ComposableAgents::RubyAgent.new(
  proc do
    puts 'What kind of holidays are you looking for?'
    {
      preferences: $stdin.gets.strip
    }
  end
)
itinerary_agent = ComposableAgents::Cline::Agent.new(
  role: 'You are a travel planner',
  objective: 'Find cities that would be the best destinations for the user\'s holidays',
  system_instructions: {
    ordered_list: [
      "Get the user preferences from the artifact named `#{ComposableAgents::PromptRenderingStrategy::MarkdownHeavy.assistant_artifact_name(:preferences)}`.",
      'Find the best cities that match those preferences.',
      "Create an artifact named `#{ComposableAgents::PromptRenderingStrategy::MarkdownHeavy.assistant_artifact_name(:cities)}` as a JSON list of those city names."
    ]
  },
  input_artifacts_contracts: {
    preferences: 'The user travel preferences'
  },
  output_artifacts_contracts: {
    cities: 'The best cities matching the user travel preferences'
  },
  model: 'deepseek/deepseek-v4-flash',
  api_key: ENV.fetch('CLINE_API_KEY', nil)
)
budget_agent = ComposableAgents::RubyAgent.new(
  proc do |input_artifacts|
    # Compute the budget from the cities list
    {
      budget: input_artifacts[:cities].size * 1000
    }
  end
)

# Compose them
puts '1. Ask the preferences agent to gather holidays preferences...'
preferences_outputs = preferences_agent.run
puts '2. Ask the itinerary agent to get a list of cities for those preferences...'
itinerary_outputs = itinerary_agent.run(**preferences_outputs)
puts '3. Ask the budget agent about money for the given itinerary...'
budget_outputs = budget_agent.run(**itinerary_outputs)

puts "Budget for the cities #{itinerary_outputs[:cities]} is $#{budget_outputs[:budget]}"
