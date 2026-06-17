require 'composable_agents'

# Example of output:
# 1. Ask the preferences agent to gather holidays preferences...
#
# Agent is asking a question:
# What are your main preferences for your next holiday? Consider aspects like: preferred destination type (beach, mountains, city, etc.), travel style (relaxing vs adventurous, luxury vs budget), activities you enjoy, and any must-have experiences.
#
# Write answer and hit Enter...
# I love to discover the culture of Italy
# 2. Ask the itinerary agent to get a list of cities for those preferences...
# 3. Ask the budget agent about money for the given itinerary...
# Budget for the cities ["Rome", "Florence", "Venice", "Naples", "Bologna", "Siena", "Verona", "Milan", "Palermo", "Lucca"] is $10000
# The conversation from the preferences agent is this one:
# [
#   {
#     "at": "2026-05-18 13:53:07 UTC",
#     "author": "User",
#     "message": "",
#     "question": false
#   },
#   {
#     "at": "2026-05-18 13:53:10 UTC",
#     "author": "Agent Executor",
#     "message": "What are your main preferences for your next holiday? Consider aspects like: preferred destination type (beach, mountains, city, etc.), travel style (relaxing vs adventurous, luxury vs budget), activities you enjoy, and any must-have experiences.",
#     "question": true
#   },
#   {
#     "at": "2026-05-18 13:53:39 UTC",
#     "author": "User",
#     "message": "I love to discover the culture of Italy",
#     "question": false
#   },
#   {
#     "at": "2026-05-18 13:53:42 UTC",
#     "author": "Agent Executor",
#     "message": "\nPerfect! I've created your holiday preferences artifact:\n\n**Your Preferences:**\n- Primary Destination: Italy\n- Travel Focus: Cultural discovery and immersion\n- Key Interests: Cultural experiences, sightseeing, historical sites\n\nWould you like to add any more details to these preferences? For example:\n- Preferred travel dates or season\n- Budget range\n- Travel companions (solo, couple, family, friends)\n- Specific regions or cities in Italy you're interested in\n- Any particular cultural experiences you want to prioritize\n\nLet me know and I can refine this further!",
#     "question": false
#   }
# ]

# Configure ai-agents as we are going to use it
require 'agents'
Agents.configure do |config|
  config.openrouter_api_key = ENV.fetch('OPENROUTER_API_KEY', nil)
  raise 'Set the OpenRouter API key in the OPENROUTER_API_KEY env variable' unless config.openrouter_api_key
end
RubyLLM::Models.refresh!

# Define agents

# Agent gathering user preferences
class PreferencesAgent < ComposableAgents::AiAgents::Agent
  prepend ComposableAgents::Mixins::ArtifactContract
  prepend ComposableAgents::Mixins::AiAgentUserInteraction

  def output_artifacts_contracts
    { preferences: 'The User\'s holidays preferences' }
  end

  def initialize
    super(
      role: 'You are a travel consultant asking for user preferences',
      objective: 'Ask the user about his/her preferences for holidays',
      system_instructions: <<~EO_INSTRUCTIONS,
        Ask the user about his/her holidays' preferences, using 1 or 2 questions maximum.
        Create an artifact named `preferences` with the user's holidays preferences.
      EO_INSTRUCTIONS
      model: 'arcee-ai/trinity-large-thinking:free'
    )
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
      system_instructions: <<~EO_INSTRUCTIONS,
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
preferences_agent = PreferencesAgent.new
preferences_outputs = preferences_agent.run
puts '2. Ask the itinerary agent to get a list of cities for those preferences...'
itinerary_outputs = ItineraryAgent.new.run(**preferences_outputs)
puts '3. Ask the budget agent about money for the given itinerary...'
budget_outputs = BudgetAgent.new.run(**itinerary_outputs)

puts "Budget for the cities #{itinerary_outputs[:cities]} is $#{budget_outputs[:budget]}"
require 'json'
puts "The conversation from the preferences agent is this one:\n#{JSON.pretty_generate(preferences_agent.conversation)}"
