require 'fileutils'

describe ComposableAgents::Cline::Agent do
  # Helper method to instantiate an AgentWithUserInteraction for testing
  #
  # @param preset_answers [Array<String>, String, nil] Answers to return when the agent asks questions
  # @param kwargs [Hash] Parameters to pass to the agent constructor
  # @return [AgentWithUserInteraction] The agent
  def described_agent(preset_answers: nil, **kwargs)
    Class.new(ComposableAgents::Cline::Agent) do
      prepend ComposableAgents::Mixins::UserInteraction

      # @return [Array<Hash{Symbol => Object}>] Questions that were asked by the agent, with the answers given
      attr_reader :question_log

      # @param preset_answers [Array<String>, nil] List of answers to return in sequence
      # @param kwargs [Hash] Parameters to pass to the agent constructor
      def initialize(preset_answers: nil, **kwargs)
        super(**kwargs)
        @preset_answers = (preset_answers.is_a?(Array) ? preset_answers.dup : [preset_answers].compact)
        @question_log = []
      end

      private

      # Answer to a question asked by the agent
      #
      # @param question [Object] The question input
      # @return [String] The answer
      def answer_to(question)
        @question_log << {
          question: question.respond_to?(:question) ? question.question : question.to_s,
          options: question.respond_to?(:options) ? question.options : nil
        }
        @preset_answers.shift || 'Default answer'
      end
    end.new(
      composable_agents_dir: '.composable_agents_test',
      strategy: ComposableAgentsTest::TestRenderingStrategy,
      preset_answers:,
      **kwargs
    )
  end

  around do |example|
    with_cline_api_key_cleared { example.call }
  end

  describe 'user interaction' do
    it 'answers the assistant\'s question if needed' do
      agent = described_agent(preset_answers: 'Test answer')
      # Run a mock Cline session that has ask_question as the last message content.
      mock_cline_for(
        agent,
        {
          stub: [
            {
              session: {
                messages: [
                  {
                    ts: 100,
                    role: 'assistant',
                    content: [
                      {
                        type: 'tool_use',
                        name: 'ask_question',
                        input: { question: 'What is your name?', options: %w[Alice Bob] }
                      }
                    ]
                  }
                ]
              }
            }
          ]
        }
      )
      agent.run(user_instructions: 'User prompt')
      expect_conversation(
        agent.conversation,
        [
          { author: 'User', message: 'RENDERED_TEXT: User prompt' },
          {
            author: 'Agent Executor',
            message: { question: 'What is your name?', options: %w[Alice Bob] },
            question: true
          },
          { author: 'User', message: 'Test answer' },
          { author: 'Agent Executor', message: '' }
        ]
      )
      # Validate that our agent was indeed called with the right question
      expect(agent.question_log).to eq [
        {
          question: 'What is your name?',
          options: %w[Alice Bob]
        }
      ]
    end
  end
end
