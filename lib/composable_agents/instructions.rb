module ComposableAgents
  # Provide a way to define instructions to be used by system and user prompts.
  # Instructions are always normalized as a list of individual instructions that each can be rendered differently depending on the rendering strategy.
  # This is used by PromptDrivenAgent agents only.
  class Instructions
    # @!group Public API

    include Enumerable

    # Constructor
    #
    # @param instructions [Object] The instructions definition. Here are the possible kinds of system instructions:
    #   - [Array<Object>] List of instruction descriptions that should be appended
    #   - [Object] Individual instruction description.
    #   An individual instruction can be one of the following:
    #     - [String] Direct instructions to be used (equivalent to { text: instructions })
    #     - [Hash\\{Symbol => Object}] A structure describing the instructions
    #       Here is the list of keys that can define different instructions:
    #       - text [String] The instructions are given as text directly.
    #       - ordered_list [Array<String>] The instructions are a precise list of steps to perform.
    #       Several keys can be used in the same Hash, and they will be treated in the order of the Hash.
    def initialize(instructions)
      # Normalize system instructions to [Array<Hash{Symbol => Object}>].
      @instructions = (instructions.is_a?(Array) ? instructions : [instructions]).map do |instructions_set|
        instructions_set.is_a?(Hash) ? instructions_set : { text: instructions_set }
      end
    end

    # Iterate over all instructions
    #
    # @yield [instruction_type, instruction] Each instruction present in these instructions.
    # @yieldparam instruction_type [Symbol] The instruction type.
    # @yieldparam instruction [Object] The instruction itself.
    def each(&)
      return enum_for(:each) unless block_given?

      @instructions.each do |instructions_set|
        instructions_set.each(&)
      end
    end
  end
end
