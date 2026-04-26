module ComposableAgentsTest
  module Helpers
    # Expect conversation to follow a given sequence.
    # This validates the authors and messages.
    # It also makes sure that timestamps are ordered properly and with a proper format.
    #
    # @param conversation [Array<Hash<Symbol, String>>] The recorded conversation
    # @param expected_conversation [Array<Hash<Symbol, String>>] The expected conversation
    def expect_conversation(conversation, expected_conversation)
      expect(conversation.map { |message| message.except(:at) }).to eq(
        # Normalize expected_conversation with some default values
        expected_conversation.map do |message|
          {
            question: false
          }.merge(message)
        end
      )
      timestamps = conversation.map { |message| message[:at] }
      expect(timestamps.sort).to eq timestamps
    end
  end
end
