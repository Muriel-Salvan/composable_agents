# Examples

This directory contains runnable Ruby scripts that demonstrate the features of `composable_agents`, presented from the simplest ones to the ones adding extra features, little by little.

Most examples that use AI agents require an API key environment variable to be set (`OPENROUTER_API_KEY` or `CLINE_API_KEY`, depending on the backend); the first one does not.

| Example | What it showcases |
|---|---|
| [compose_without_ai.rb](./compose_without_ai.rb) | Two plain `RubyAgent` agents (itinerary + budget) composed with plain Ruby procs — no AI involved. Artifacts flow from one agent to the next. |
| [compose_with_ai.rb](./compose_with_ai.rb) | Adds an `AiAgents::Agent` backed by OpenRouter for the itinerary step; user preferences are still gathered from `$stdin`. |
| [compose_with_cline.rb](./compose_with_cline.rb) | Same composition as `compose_with_ai`, but using the `ComposableAgents::Cline::Agent` backend (cline-rb) for the itinerary step. Requires `CLINE_API_KEY` instead of `OPENROUTER_API_KEY`. |
| [using_artifacts_contracts.rb](./using_artifacts_contracts.rb) | Adds the `ArtifactContract` mixin so agents declare `input_artifacts_contracts` / `output_artifacts_contracts`, using a class-based agent style. |
| [with_user_interaction.rb](./with_user_interaction.rb) | Adds the `AiAgentUserInteraction` mixin so the AI agent can ask the user clarifying questions mid-execution; inspects `agent.conversation` afterward. |
| [persist_and_resume.rb](./persist_and_resume.rb) | Adds the `Resumable` mixin on an orchestrating `MainAgent`; a workflow is interrupted and then resumed, reusing completed steps. State is saved under `.composable_agents/runs/<run_id>`. |
| [retriable_artifacts.rb](./retriable_artifacts.rb) | Adds the `RetriableArtifacts` mixin (requires `ArtifactContract` + `Retriable`) on a `PromptDrivenAgent`; automatically re-runs when contracted output artifacts are missing or in error, up to `artifacts_errors_max_retries`. |

## How to run

Each example is a standalone script:

```sh
ruby examples/compose_without_ai.rb
```

For the AI-backed examples, make sure the corresponding API key is set first:

```sh
export OPENROUTER_API_KEY=your-key-here   # for compose_with_ai.rb
export CLINE_API_KEY=your-key-here        # for compose_with_cline.rb

ruby examples/compose_with_ai.rb
ruby examples/compose_with_cline.rb
```
