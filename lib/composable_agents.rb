require 'zeitwerk'

Zeitwerk::Loader.for_gem.setup

# All composable agents are accessible here.
# A composable agent:
# * is stateless,
# * takes input artifacts,
# * outputs artifacts,
# * can internally call LLMs, other agents, workflows, tools...
module ComposableAgents
end
