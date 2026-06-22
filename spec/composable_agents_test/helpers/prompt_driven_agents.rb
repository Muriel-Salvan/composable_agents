module ComposableAgentsTest
  module Helpers
    # Helpers for prompt-driven agents testing
    module PromptDrivenAgents
      # Expect conversation to follow a given sequence.
      # This validates the authors and messages.
      # It also makes sure that timestamps are ordered properly and with a proper format.
      #
      # @param conversation [Array<Hash{Symbol => Object}>] The recorded conversation.
      # @param expected_conversation [Array<Hash{Symbol => Object}>] The expected conversation.
      #   If object values of the expected conversation ar Regexp, then pattern matching is used instead of equality.
      def expect_conversation(conversation, expected_conversation)
        expect(conversation.size).to eq expected_conversation.size
        conversation.zip(expected_conversation).each do |message, expected_message|
          # Normalize messages with some default values
          message = message.except(:at)
          expected_message = {
            question: false
          }.merge(expected_message)
          expect(message.size).to eq expected_message.size
          message.each do |message_attr, message_value|
            if expected_message[message_attr].is_a?(Regexp)
              expect(message_value).to match expected_message[message_attr]
            else
              expect(message_value).to eq expected_message[message_attr]
            end
          end
        end
        timestamps = conversation.map { |message| message[:at] }
        expect(timestamps.sort).to eq timestamps
      end

      # Check that an agent received a list of user prompts.
      # Only check that expected user prompts are included into real ones, as real ones may convey
      #   more information that isn't relevant with the test case (context...).
      #
      # @param agent [ComposableAgent::PromptDrivenAgent] Prompt-driven agent to check
      # @param expected_user_prompts [Array<String>] List of expected user prompts
      def expect_agent_received_prompts(agent, expected_user_prompts)
        received_user_prompts = agent.spy[:user_prompts]
        expect(received_user_prompts.size).to eq expected_user_prompts.size
        received_user_prompts.zip(expected_user_prompts).each do |received_user_prompt, expected_user_prompt|
          expect(received_user_prompt).to include(expected_user_prompt)
        end
      end
    end
  end
end
