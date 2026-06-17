module ComposableAgentsTest
  # Provide spy capabilities on prompt-driven agents used in tests
  module PromptDrivenAgentSpies
    attr_accessor(*%i[spy_system_prompt spy_user_prompts])

    def spy
      {
        role: @role,
        objective: @objective,
        system_instructions: @system_instructions,
        constraints: @constraints,
        system_prompt: spy_system_prompt,
        user_prompts: spy_user_prompts
      }
    end
  end
end
