describe ComposableAgents::Mixins::UserInteraction do
  it 'tracks question and answer in agent conversation when ask is called' do
    test_agent = Class.new(ComposableAgents::PromptDrivenAgent) do
      prepend ComposableAgents::Mixins::UserInteraction

      private

      def answer_to(question)
        "[#{question}]: 42"
      end
    end.new(name: 'test-agent')

    expect(test_agent.ask('What is the meaning of life?')).to eq('[What is the meaning of life?]: 42')
    expect_conversation(
      test_agent.conversation,
      [
        {
          author: 'Agent test-agent',
          message: 'What is the meaning of life?',
          question: true
        },
        {
          author: 'User',
          message: '[What is the meaning of life?]: 42'
        }
      ]
    )
  end

  it 'uses default terminal input when agent does not define custom answer_to method' do
    test_agent = Class.new(ComposableAgents::PromptDrivenAgent) do
      prepend ComposableAgents::Mixins::UserInteraction
    end.new(name: 'test-agent')

    allow($stdin).to receive(:gets).and_return('This is my answer from terminal')
    allow($stdout).to receive(:puts)

    expected_answer = 'This is my answer from terminal'
    expect(test_agent.ask('Please answer this question?')).to eq(expected_answer)
    expect_conversation(
      test_agent.conversation,
      [
        {
          author: 'Agent test-agent',
          message: 'Please answer this question?',
          question: true
        },
        {
          author: 'User',
          message: expected_answer
        }
      ]
    )
  end
end
