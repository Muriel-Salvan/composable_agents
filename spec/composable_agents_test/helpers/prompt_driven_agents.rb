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
    end
  end
end
