describe ComposableAgents::Cline::Agent do
  describe 'constructor parameters' do
    # Run an agent and stub its output to dump the content of its providers settings.
    #
    # @param kwargs [Hash] Parameters to give to the agent's constructor
    # @return [Hash] The corresponding providers' settings that this agent was given
    def capture_provider_settings(**kwargs)
      agent = cline_agent(**kwargs)
      mock_cline_for(
        agent,
        {
          stdout: {
            eval: <<~EO_RUBY
              JSON.parse(File.read("\#{config_dir}/data/settings/providers.json")).to_json
            EO_RUBY
          }
        }
      )
      agent.run
      JSON.parse(agent.conversation.last[:message], symbolize_names: true)
    end

    describe 'name' do
      it 'defaults to "Executor"' do
        expect(cline_agent.name).to eq 'Executor'
      end

      it 'accepts a custom name' do
        expect(cline_agent(name: 'Test Assistant').name).to eq 'Test Assistant'
      end
    end

    describe 'provider' do
      it 'defaults to "cline"' do
        provider_settings = capture_provider_settings
        expect(provider_settings[:lastUsedProvider]).to eq 'cline'
        expect(provider_settings[:providers][:cline][:settings][:provider]).to eq 'cline'
      end

      it 'accepts a custom provider string' do
        provider_settings = capture_provider_settings(provider: 'openai')
        expect(provider_settings[:lastUsedProvider]).to eq 'openai'
        expect(provider_settings[:providers][:openai][:settings][:provider]).to eq 'openai'
      end
    end

    describe 'model' do
      it 'defaults to "anthropic/claude-sonnet-4.6"' do
        expect(capture_provider_settings[:providers][:cline][:settings][:model]).to eq 'anthropic/claude-sonnet-4.6'
      end

      it 'accepts a custom model string' do
        expect(capture_provider_settings(model: 'gpt-4o')[:providers][:cline][:settings][:model]).to eq 'gpt-4o'
      end

      it 'accepts a nil model' do
        expect(capture_provider_settings(model: nil)[:providers][:cline][:settings][:model]).to be_nil
      end
    end

    describe 'api_key' do
      it 'defaults to nil when CLINE_API_KEY is not set' do
        expect(capture_provider_settings[:providers][:cline][:settings][:apiKey]).to be_nil
      end

      it 'defaults to ENV["CLINE_API_KEY"] when set' do
        ENV['CLINE_API_KEY'] = 'env-key-123'
        expect(capture_provider_settings[:providers][:cline][:settings][:apiKey]).to eq 'env-key-123'
      end

      it 'prefers an explicit api_key over ENV' do
        ENV['CLINE_API_KEY'] = 'env-key-123'
        expect(capture_provider_settings(api_key: 'explicit-key-456')[:providers][:cline][:settings][:apiKey]).to eq 'explicit-key-456'
      end

      it 'accepts an empty api_key' do
        expect(capture_provider_settings(api_key: '')[:providers][:cline][:settings][:apiKey]).to eq ''
      end

      it 'accepts a nil api_key' do
        expect(capture_provider_settings(api_key: nil)[:providers][:cline][:settings][:apiKey]).to be_nil
      end
    end

    describe 'configure_provider' do
      it 'does not change the provider settings if not given' do
        expect(capture_provider_settings[:providers][:cline][:settings]).to eq(
          {
            provider: 'cline',
            model: 'anthropic/claude-sonnet-4.6'
          }
        )
      end

      it 'gets the provider settings as a parameter and can modify it' do
        expect(
          capture_provider_settings(
            provider: 'openai',
            configure_provider: proc do |settings|
              expect(settings.provider).to eq 'openai'
              settings.model = 'my-new-model'
            end
          )[:providers][:openai][:settings][:model]
        ).to eq 'my-new-model'
      end
    end

    describe 'configure_global' do
      # Run an agent and stub its output to dump the content of its global settings.
      #
      # @param kwargs [Hash] Parameters to give to the agent's constructor
      # @return [Hash] The corresponding global settings that this agent was given
      def capture_global_settings(**kwargs)
        agent = cline_agent(**kwargs)
        mock_cline_for(
          agent,
          {
            stdout: {
              eval: <<~EO_RUBY
                JSON.parse(File.read("\#{config_dir}/data/settings/global-settings.json")).to_json
              EO_RUBY
            }
          }
        )
        agent.run
        JSON.parse(agent.conversation.last[:message], symbolize_names: true)
      end

      it 'does not change the global settings if not given' do
        expect(capture_global_settings).to eq(
          {
            autoUpdateEnabled: false
          }
        )
      end

      it 'gets the global settings as a parameter and can modify it' do
        expect(
          capture_global_settings(
            configure_global: proc do |settings|
              settings.auto_update_enabled = true
              settings.telemetry_opt_out = true
              settings.disabled_tools = %w[tool1 tool2]
            end
          )
        ).to eq(
          {
            autoUpdateEnabled: true,
            telemetryOptOut: true,
            disabledTools: %w[tool1 tool2]
          }
        )
      end
    end

    describe 'cli_options' do
      # Capture the CLI options that were given to Cline CLI.
      # Don't capture the --config option.
      #
      # @param cli_options [Hash] CLI options to give to the agent's constructor.
      # @return [Array<String>] The CLI options given to Cline CLI.
      def capture_cli_options(cli_options = {})
        agent = cline_agent(cli_options:)
        mock_cline_for(agent)
        agent.run
        agent.cli_stub.issued_commands.last[:command][2..]
      end

      it 'defaults to no option' do
        expect(capture_cli_options).to eq [
          '--system', 'SYSTEM_PROMPT[]',
          'USER_PROMPT[]'
        ]
      end

      it 'passes plan: true to the CLI task command' do
        expect(capture_cli_options(plan: true)).to eq [
          '--system', 'SYSTEM_PROMPT[]',
          '--plan',
          'USER_PROMPT[]'
        ]
      end

      it 'passes model option to the CLI task command' do
        expect(capture_cli_options(model: 'custom-cli-model')).to eq [
          '--system', 'SYSTEM_PROMPT[]',
          '--model', 'custom-cli-model',
          'USER_PROMPT[]'
        ]
      end

      it 'passes auto_approve: true to the CLI task command' do
        expect(capture_cli_options(auto_approve: true)).to eq [
          '--system', 'SYSTEM_PROMPT[]',
          '--auto-approve',
          'USER_PROMPT[]'
        ]
      end

      it 'passes thinking option to the CLI task command' do
        expect(capture_cli_options(thinking: 'high')).to eq [
          '--system', 'SYSTEM_PROMPT[]',
          '--thinking', 'high',
          'USER_PROMPT[]'
        ]
      end

      it 'passes timeout option to the CLI task command' do
        expect(capture_cli_options(timeout: 300)).to eq [
          '--system', 'SYSTEM_PROMPT[]',
          '--timeout', '300',
          'USER_PROMPT[]'
        ]
      end

      it 'passes multiple options simultaneously' do
        expect(capture_cli_options(plan: true, model: 'multi-model', auto_approve: true)).to eq [
          '--system', 'SYSTEM_PROMPT[]',
          '--plan',
          '--model', 'multi-model',
          '--auto-approve',
          'USER_PROMPT[]'
        ]
      end

      it 'passes data_dir option to the CLI task command' do
        expect(capture_cli_options(data_dir: '/custom/data/path')).to eq [
          '--system', 'SYSTEM_PROMPT[]',
          '--data-dir', '/custom/data/path',
          'USER_PROMPT[]'
        ]
      end

      it 'does not include false options' do
        expect(capture_cli_options(plan: false)).to eq [
          '--system', 'SYSTEM_PROMPT[]',
          'USER_PROMPT[]'
        ]
      end
    end
  end
end
