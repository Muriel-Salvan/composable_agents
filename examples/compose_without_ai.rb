require 'composable_agents'

# Example of output:
# 1. Ask the itinerary agent about cities...
# 2. Ask the budget agent about money for a given itinerary...
# Budget for the cities ["London", "Madrid", "Paris"] is $3000

# Define agents
itinerary_agent = ComposableAgents::RubyAgent.new(
  proc do
    # Find the cities we want to visit
    {
      cities: %w[London Madrid Paris]
    }
  end
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
puts '1. Ask the itinerary agent about cities...'
itinerary_outputs = itinerary_agent.run
puts '2. Ask the budget agent about money for a given itinerary...'
budget_outputs = budget_agent.run(**itinerary_outputs)

puts "Budget for the cities #{itinerary_outputs[:cities]} is $#{budget_outputs[:budget]}"
