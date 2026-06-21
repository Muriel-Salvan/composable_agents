require 'json'

module ComposableAgentsTest
  # Test specific PromptRenderingStrategy that adds the context in user prompts
  module TestRenderingStrategyWithContext
    include TestRenderingStrategy

    # Render the user prompt
    # The following instance variables are accessible to render the prompt:
    # - `@role`
    # - `@objective`
    # - `@constraints`
    #
    # @param rendered_instructions [String, nil] The rendered instructions, or nil if none
    # @param input_artifacts [Hash{Symbol => Object}] The input artifacts content for which we render this prompt, per artifact name
    # @return [String] The rendered user prompt
    def render_user_prompt(rendered_instructions, input_artifacts:)
      "USER_PROMPT[#{rendered_instructions}#{
        " with #{input_artifacts.map { |name, content| "#{name} (#{content})" }.join(', ')}" unless input_artifacts.empty?
      }#{
        # Don't use to_json as it translates < > into unicode characters.
        " and context <<<#{JSON.dump(@context)}>>>" if @context
      }]"
    end
  end
end
