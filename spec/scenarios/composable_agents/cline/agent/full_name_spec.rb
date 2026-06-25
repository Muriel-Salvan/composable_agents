describe ComposableAgents::Cline::Agent, '#full_name' do
  it 'includes the agent name, provider, and model when name is set' do
    expect(cline_agent(name: 'MyAgent', provider: 'openai', model: 'gpt-4o').full_name).to eq 'MyAgent (Cline openai/gpt-4o)'
  end

  it 'uses "Unnamed" when the agent name is nil' do
    expect(cline_agent(provider: 'anthropic', model: 'claude-3-5-sonnet').full_name).to eq 'Unnamed (Cline anthropic/claude-3-5-sonnet)'
  end
end
