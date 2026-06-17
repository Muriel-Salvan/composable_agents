require 'composable_agents'

# Example of output:
# 1. Ask the preferences agent to gather holidays preferences...
#
# Agent is asking a question:
# What are your top 3 preferences for a holiday? For example: destination type (beach, city, nature), budget range, travel dates, travel style (luxury, adventure, relaxation), or any specific requirements?
#
# Write answer and hit Enter...
# Trekking in Central Europe
#
# Agent is asking a question:
# What are your preferred travel dates and budget range for this trekking trip in Central Europe?
#
# Write answer and hit Enter...
# Economy during summer
# 2. Ask the itinerary agent to get a list of cities for those preferences...
# !!! Flow has been interrupted !!!
#
# 1. Ask the preferences agent to gather holidays preferences...
# 2. Ask the itinerary agent to get a list of cities for those preferences...
# 3. Ask the budget agent about money for the given itinerary...
# Budget for the cities ["Poprad, Slovakia", "Zakopane, Poland", "Bled, Slovenia", "Kranjska Gora, Slovenia", "Berchtesgaden, Germany", "Innsbruck, Austria"] is $6000

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

# Agent orchestrating and persisting the whole workflow
class MainAgent < ComposableAgents::Agent
  prepend ComposableAgents::Mixins::Resumable

  def initialize(fail_after_itinerary: false, **kwargs)
    super(**kwargs)
    @fail_after_itinerary = fail_after_itinerary
  end

  def run
    puts '1. Ask the preferences agent to gather holidays preferences...'
    step_agent(PreferencesAgent.new)
    puts '2. Ask the itinerary agent to get a list of cities for those preferences...'
    step_agent(ItineraryAgent.new)
    raise 'Simulate an interruption' if @fail_after_itinerary

    puts '3. Ask the budget agent about money for the given itinerary...'
    step_agent(BudgetAgent.new)
    puts "Budget for the cities #{@artifacts[:cities]} is $#{@artifacts[:budget]}"
  end
end

# Compose them
# Run the agent and interrupt it.
# Its state will be saved in .composable_agents/runs/test_run.
begin
  MainAgent.new(fail_after_itinerary: true, run_id: 'test_run').run
rescue RuntimeError
  puts '!!! Flow has been interrupted !!!'
  puts
end
# Run again: the first 2 steps will be reused
MainAgent.new(run_id: 'test_run').run
