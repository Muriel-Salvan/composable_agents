require 'cline'

module ComposableAgents
  # All agents from this module work with the awesome cline-rb Rubygem
  module Cline
    # Missin skill error
    class MissingSkillError < RuntimeError
    end

    # Agent implementation that uses an ai-agent's AgentRunner.
    class Agent < PromptDrivenAgent
      # @!group Public API

      prepend Mixins::ArtifactContract

      # Initialize a new agent that uses the Cline CLI in a dedicated config
      #
      # @param strategy [Module] The prompt rendering strategy
      # @param provider [String] Provider to be used
      # @param model [String] Model to be used
      # @param api_key [String] API key to be used
      # @param configure_provider [#call(provider_settings), nil] Optional block used to configure the provider settings
      #   * Param provider_settings [Cline::Providers::ProviderSettings] Settings that can be tuned for this agent
      # @param configure_global [#call(global_settings), nil] Optional block used to configure the global settings
      #   * Param global_settings [Cline::GlobalSettings] Settings that can be tuned for this agent
      # @param skills [Array<String>] List of skills to allow for this agent
      # @param cli_options [Hash{Symbol => Object}] Task options to give to Cline CLI (see Cline::Cli.COMMANDS)
      def initialize(
        *args,
        strategy: PromptRenderingStrategy::MarkdownHeavy,
        provider: 'cline',
        model: 'anthropic/claude-sonnet-4.6',
        api_key: ENV.fetch('CLINE_API_KEY', nil),
        configure_provider: nil,
        configure_global: nil,
        skills: [],
        cli_options: {},
        **kwargs
      )
        super(*args, strategy:, **kwargs)
        @provider = provider
        @model = model
        @api_key = api_key ? ::Cline::SecretString.new(api_key.dup) : nil
        @configure_provider = configure_provider
        @configure_global = configure_global
        @skills = skills
        @cli_options = cli_options
        @context = []
      end

      # Return the full name of the agent.
      # This method is intended to be overridden by subclasses to give better full names, tailored to the kind of agent.
      # The full name can be used in logs and traces to better identify the agent.
      #
      # @return [String] The agent's full name
      def full_name
        "#{name || 'Unnamed'} (Cline #{@provider}/#{@model})"
      end

      # @!group Internal

      # Export the agent state for persistence
      #
      # @return [Object] Serialized state that can be marshalled to JSON
      def export_state
        super.merge(deep_transform_keys(context: @context, &:to_s))
      end

      # Import the agent state from persistence
      #
      # @param state [Object] Serialized state
      def import_state(state)
        super
        @context = deep_transform_keys(state, &:to_sym)[:context]
      end

      private

      # Process a user prompt.
      #
      # @param user_prompt [String] The rendered user prompt
      # @return [String] The output of the prompt
      def prompt(user_prompt)
        # Add the context to the prompt if it is the first prompt of this Cline CLI session
        full_user_prompt =
          if @context.empty?
            user_prompt
          else
            <<~EO_SECTION
              # Previous sessions context

              Here is the conversation from a previous session for context:

              ```json
              #{JSON.dump(@context)}
              ```

              Continue with the task, building on the work from the session above.

              #{user_prompt}
            EO_SECTION
          end
        # Call the Cline CLI
        result = cline_cli.task(
          full_user_prompt,
          system: @system_prompt,
          on_question: respond_to?(:ask, true) ? proc { |question| ask(question) } : nil,
          on_message: proc do |message, _last, _previous_version|
            # Look for any output artifact from the answers
            if message.role == 'assistant'
              message.content&.each do |content|
                parse_output_artifacts(content.text) if content.type == 'text' && content.text
              end
            end
          end,
          **@cli_options
        )
        raise "Error: #{result[:error].err.message}".strip if result[:error]

        # Keep the context in case we need to resume it
        if cline_cli.session&.messages
          @context.concat(
            cline_cli.session.messages.map.with_index do |message, idx_message|
              {
                role: message.role,
                content: message.content.map.with_index do |content, idx_content|
                  {
                    type: content.type,
                    text: (
                      if idx_message.zero? && idx_content.zero?
                        # First message is the user prompt, but we don't want to include the context from it
                        user_prompt
                      else
                        content.text
                      end
                    ),
                    input:
                      if content.input
                        {
                          question: content.input.question,
                          options: content.input.options
                        }.compact
                      end,
                    content: content.content
                  }.compact
                end
              }
            end
          )
        end

        result[:message]&.content&.last&.text || ''
      end

      # Get the Cline CLI instance to use for this agent.
      # Memoize it.
      #
      # @return [::Cline::Cli] The Cline CLI instance to be used
      def cline_cli
        @cline_cli ||= begin
          # Resolve all the skills and their dependencies (taken from their YAML front matter).
          selected_skills = []
          @skills.each do |skill|
            find_skill(skill, selected_skills)
          end
          # Setup the temporary Cline global config dir
          agent_tmp_dir = "#{@composable_agents_dir}/tmp/#{Time.now.utc.strftime('%F-%H-%M-%S')}#{"-#{name.gsub(/[^\w.]/, '_')}" if name}"
          ::Cline.configure do |config|
            config.debug = Mixins::Logger.debug?
            config.temp_dir_root = "#{agent_tmp_dir}/cline-rb"
          end
          cline_config = ::Cline::Config.open("#{agent_tmp_dir}/cline_config", create: true)
          # Copy all selected global skills in this config's skills
          if ::Cline::Config.global.skills
            (::Cline::Config.global.skills.keys & selected_skills).each do |skill_name|
              new_skill = cline_config.skills.new(skill_name)
              new_skill.files.replace(::Cline::Config.global.skills[skill_name].files)
              new_skill.enable
              log_debug "[Cline] - Enable global skill #{skill_name}"
              new_skill.save
            end
          end
          # Enable/disable project skills to make sure only selected ones are enabled
          ::Cline::Config.project&.skills&.each do |skill_name, skill|
            selected_skill = selected_skills.include?(skill_name)
            next if skill.enabled? == selected_skill

            if selected_skill
              log_debug "[Cline] - Enable project skill #{skill_name}"
              skill.enable
            else
              log_debug "[Cline] - Disable project skill #{skill_name}"
              skill.disable
            end
            skill.save
          end
          # TODO: When using skillkit, also create a global rule only containing selected skills (use skillkit if possible to generate it).
          #   Or maybe just don't use skillkit to generate this AGENTS.md file. Skills should be discoverable without it. To be tested.
          # Set the configuration
          providers = cline_config.providers(create: true)
          providers.version = 1
          providers.last_used_provider = @provider
          providers.providers = {
            @provider => {
              token_source: 'manual',
              updated_at: Time.now.utc.strftime('%FT%T.%LZ'),
              settings: {
                provider: @provider,
                api_key: @api_key,
                model: @model
              }
            }
          }
          @configure_provider&.call(providers.providers[@provider].settings)
          providers.save
          global_settings = cline_config.global_settings(create: true)
          # Don't update the Cline CLI
          global_settings.auto_update_enabled = false
          @configure_global&.call(global_settings)
          global_settings.save
          cline_config.cli(stdout_echo: Mixins::Logger.debug?, verbose: Mixins::Logger.debug?)
        end
      end

      # Find a skill among the current Cline environment (global and project) and recursively finds all its dependencies.
      #
      # @param skill [String] The skill name we are looking for
      # @param found_skills [Array<String>] In place list of skills that are already found (so we don't need to look for them again)
      #   If found, the skill and its dependencies will be added to this array.
      def find_skill(skill, found_skills)
        return if found_skills.include?(skill)

        # Find the skill among the global or local configs
        found_skill = (::Cline::Config.global&.skills && ::Cline::Config.global.skills[skill]) ||
          (::Cline::Config.project&.skills && ::Cline::Config.project.skills[skill])
        raise MissingSkillError, "Cline Skill #{skill} is unknown, neither in the global nor project configurations" unless found_skill

        found_skills << skill
        # Now look for its dependencies
        (found_skill.yaml_front_matter.dig(*%i[metadata dependencies]) || []).each do |skill_dep|
          find_skill(skill_dep, found_skills)
        end
      end
    end
  end
end
