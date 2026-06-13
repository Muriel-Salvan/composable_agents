module ComposableAgentsTest
  # Provide spy capabilities on Cline agents used in tests
  module ClineAgentSpies
    include PromptDrivenAgentSpies

    # @return [ClineTest::CliStub] The Cline CLI stub used for this agent
    attr_accessor :cli_stub

    # @return [String] The system prompt to be spied
    def spy_system_prompt
      @system_prompt
    end

    # @return [Array<String>] The list of user prompts to be spied
    def spy_user_prompts
      cli_stub.issued_commands.map { |command_desc| command_desc[:command].last }
    end
  end
end
