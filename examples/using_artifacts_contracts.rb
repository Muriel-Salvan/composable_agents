require 'composable_agents'

# Example of output:
# 1. Ask the preferences agent to gather holidays preferences...
# What kind of holidays are you looking for?
# Seaside in France
# 2. Ask the itinerary agent to get a list of cities for those preferences...
# 3. Ask the budget agent about money for the given itinerary...
# Budget for the cities ["Nice", "Cannes", "Saint-Tropez", "Marseille", "Biarritz", "Antibes", "Toulon", "La Rochelle", "Montpellier", "Calais"] is $10000        

# Configure ai-agents as we are going to use it
require 'agents'
Agents.configure do |config|
  config.openrouter_api_key = ENV.fetch('OPENROUTER_API_KEY', nil)
  raise 'Set the OpenRouter API key in the OPENROUTER_API_KEY env variable' unless config.openrouter_api_key
end
RubyLLM::Models.refresh!

# Define agents

# Agent gathering user preferences
class PreferencesAgent < ComposableAgents::Agent
  prepend ComposableAgents::Mixins::ArtifactContract

  def output_artifacts_contracts
    { preferences: 'The User\'s holidays preferences' }
  end

  def run
    puts 'What kind of holidays are you looking for?'
    {
      preferences: $stdin.gets.strip
    }
  end
end

# Agent computing itineraries
class ItineraryAgent < ComposableAgents::AiAgents::Agent
  prepend ComposableAgents::Mixins::ArtifactContract

  def input_artifacts_contracts
    { preferences: 'The User\'s holidays preferences' }
  end

  def output_artifacts_contracts
    { cities: 'The list of cities to visit' }
  end

  def initialize
    super(
      role: 'You are a travel planner',
      objective: 'Find cities that would be the best destinations for the user\'s holidays',
      instructions: <<~EO_INSTRUCTIONS,
        Get the user preferences from the artifact named `preferences`.
        Find the best cities that match those preferences.
        Create an artifact named `cities` as a JSON list of those city names.
      EO_INSTRUCTIONS
      model: 'arcee-ai/trinity-large-thinking:free'
    )
  end
end

# Agent computing budget
class BudgetAgent < ComposableAgents::Agent
  prepend ComposableAgents::Mixins::ArtifactContract

  def input_artifacts_contracts
    { cities: 'The list of cities to visit' }
  end

  def output_artifacts_contracts
    { budget: 'The total budget' }
  end

  def run(**input_artifacts)
    {
      budget: JSON.parse(input_artifacts[:cities]).size * 1000
    }
  end
end

# Compose them
puts '1. Ask the preferences agent to gather holidays preferences...'
preferences_outputs = PreferencesAgent.new.run
puts '2. Ask the itinerary agent to get a list of cities for those preferences...'
itinerary_outputs = ItineraryAgent.new.run(**preferences_outputs)
puts '3. Ask the budget agent about money for the given itinerary...'
budget_outputs = BudgetAgent.new.run(**itinerary_outputs)

puts "Budget for the cities #{itinerary_outputs[:cities]} is $#{budget_outputs[:budget]}"
