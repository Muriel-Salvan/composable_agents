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
RubyLLM.models.refresh

# Define agents
preferences_agent = ComposableAgents::RubyAgent.new(
  proc do
    puts 'What kind of holidays are you looking for?'
    {
      preferences: $stdin.gets.strip
    }
  end
)
# AI-backed agent that suggests holiday destination cities.
class ItineraryAgent < ComposableAgents::AiAgents::Agent
  prepend ComposableAgents::Mixins::ArtifactContract
  prepend ComposableAgents::Mixins::Retriable
  prepend ComposableAgents::Mixins::RetriableArtifacts

  private

  def prompt(user_prompt)
    response = super
    parse_output_artifacts(response) if response.is_a?(String)
    response
  end
end

itinerary_agent = ItineraryAgent.new(
  artifacts_errors_max_retries: 2,
  output_artifacts_contracts: {
    cities: 'A JSON array of city names matching the user\'s holiday preferences'
  },
  strategy: ComposableAgents::PromptRenderingStrategy::MarkdownHeavy,
  role: 'You are a travel planner',
  objective: 'Find cities that would be the best destinations for the user\'s holidays',
  system_instructions: <<~EO_INSTRUCTIONS,
    Get the user preferences from the artifact named `preferences`.
    Find the best cities that match those preferences.
    Return the `cities` artifact in the JSON output block specified in the system prompt.
    Its content must be a valid JSON array of city names, not prose.
  EO_INSTRUCTIONS
  model: 'nvidia/nemotron-3.5-lightning:free'
)
budget_agent = ComposableAgents::RubyAgent.new(
  proc do |input_artifacts|
    # Compute the budget from the cities list
    cities = input_artifacts[:cities]
    cities = JSON.parse(cities) if cities.is_a?(String)
    {
      budget: cities.size * 1000
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
