module ComposableAgentsTest
  # Test specific PromptRenderingStrategy that adds the context in user prompts
  module TestRenderingStrategyWithContext
    include TestRenderingStrategy

    def render_user_prompt(user_message, input_artifacts: {})
      "USER_PROMPT[#{user_message}#{
        " with #{input_artifacts.map { |name, content| "#{name} (#{content})" }.join(', ')}" unless input_artifacts.empty?
      }#{
        " and context <<<#{@context.to_json}>>>" if @context
      }]"
    end
  end
end
