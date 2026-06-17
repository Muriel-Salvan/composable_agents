require 'composable_agents'

# Example of output:
# 1. Ask the preferences agent to gather holidays preferences...
# What kind of holidays are you looking for?
# Visiting museums in Spain
# 2. Ask the itinerary agent to get a list of cities for those preferences...
# 3. Ask the budget agent about money for the given itinerary...
# Budget for the cities ["Madrid", "Barcelona", "Bilbao", "Seville", "Valencia", "Malaga", "Granada"] is $7000

# Configure ai-agents as we are going to use it
require 'agents'
Agents.configure do |config|
  config.openrouter_api_key = ENV.fetch('OPENROUTER_API_KEY', nil)
  raise 'Set the OpenRouter API key in the OPENROUTER_API_KEY env variable' unless config.openrouter_api_key
end
RubyLLM::Models.refresh!

# Define agents
preferences_agent = ComposableAgents::RubyAgent.new(
  proc do
    puts 'What kind of holidays are you looking for?'
    {
      preferences: $stdin.gets.strip
    }
  end
)
itinerary_agent = ComposableAgents::AiAgents::Agent.new(
  role: 'You are a travel planner',
  objective: 'Find cities that would be the best destinations for the user\'s holidays',
  system_instructions: <<~EO_INSTRUCTIONS,
    Get the user preferences from the artifact named `preferences`.
    Find the best cities that match those preferences.
    Create an artifact named `cities` as a JSON list of those city names.
  EO_INSTRUCTIONS
  model: 'arcee-ai/trinity-large-thinking:free'
)
budget_agent = ComposableAgents::RubyAgent.new(
  proc do |input_artifacts|
    # Compute the budget from the cities list
    {
      budget: JSON.parse(input_artifacts[:cities]).size * 1000
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
