module ComposableAgentsTest
  # Test specific PromptRenderingStrategy that adds the context in user prompts
  module TestRenderingStrategyWithContext
    include TestRenderingStrategy

    def render_user_prompt(rendered_instructions, input_artifacts: {})
      "USER_PROMPT[#{rendered_instructions}#{
        " with #{input_artifacts.map { |name, content| "#{name} (#{content})" }.join(', ')}" unless input_artifacts.empty?
      }#{
        " and context <<<#{@context.to_json}>>>" if @context
      }]"
    end
  end
end
