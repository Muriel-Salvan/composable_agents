require 'yaml'

describe ComposableAgents::Cline::Agent do
  describe 'skills' do
    # Run an agent and stub its output to dump the skills configuration.
    #
    # @param kwargs [Hash] Parameters to give to the agent's constructor
    # @return [Hash{Symbol => Object}] Description of the skills:
    #   - config_dir [String] The config directory that was used for this run.
    #   - skills [Hash{String => String}] All skill files content found, per skill file name.
    def capture_skills(**kwargs)
      agent = described_class.new(
        composable_agents_dir: '.composable_agents_test',
        strategy: ComposableAgentsTest::TestRenderingStrategy,
        **kwargs
      )
      mock_cline_for(
        agent,
        {
          stdout: {
            eval: <<~EO_RUBY
              {
                config_dir:,
                skills: (Dir.glob("\#{config_dir}/skills/**/*") + Dir.glob('.cline/skills/**/*')).to_h do |skill_file|
                  [
                    skill_file,
                    File.directory?(skill_file) ? nil : File.read(skill_file)
                  ]
                end.compact
              }.to_json
            EO_RUBY
          }
        }
      )
      agent.run
      JSON.parse(agent.conversation.last[:message]).transform_keys(&:to_sym)
    end

    # Create a skill in a Cline config directory
    #
    # @param config_dir [String] The config directory
    # @param name [String] The skill name
    # @param description [String] The skill description
    # @param enabled [Boolean] Is the skill enabled?
    # @param dependencies [Array<String>, nil] List of the skill's dependencies, or nil if none
    # @param content [String] Skill content
    # @param extra_files [Hash{String => String}] Extra files content to be created, per relative path from the skill's directory
    def create_skill(config_dir, name, description: 'Description', enabled: true, dependencies: nil, content: '', extra_files: {})
      front_matter = {
        'name' => name,
        'description' => description
      }
      front_matter['metadata'] = { 'dependencies' => dependencies } if dependencies
      front_matter['disabled'] = true unless enabled
      # Write all files
      skill_dir = "#{config_dir}/skills/#{name}"
      extra_files.merge(
        {
          'SKILL.md' => "---\n#{YAML.dump(front_matter).sub(/\A---\n/, '')}---\n#{content}\n"
        }
      ).each do |path, file_content|
        full_path = "#{skill_dir}/#{path}"
        FileUtils.mkdir_p(File.dirname(full_path))
        File.write(full_path, file_content)
      end
    end

    around do |example|
      FileUtils.rm_rf('.composable_agents_test')
      # Set a test project config directory
      project_dir = '.composable_agents_test/cline_project'
      FileUtils.rm_rf project_dir
      project_config_dir = "#{project_dir}/.cline"
      FileUtils.mkdir_p project_config_dir
      # Make sure caches of Cline::Config.global and Cline::Config.project are cleared
      original_global = Cline::Config.instance_variable_get(:@global)
      begin
        Cline::Config.remove_instance_variable(:@global) if Cline::Config.instance_variable_defined?(:@global)
        original_project = Cline::Config.instance_variable_get(:@project)
        begin
          Cline::Config.remove_instance_variable(:@project) if Cline::Config.instance_variable_defined?(:@project)
          # Run the example from the project directory
          Dir.chdir(project_dir) { example.run }
        ensure
          Cline::Config.instance_variable_set(:@project, original_project)
        end
      ensure
        Cline::Config.instance_variable_set(:@global, original_global)
      end
    end

    before do
      # Mock the global config directory
      mocked_user_home_dir = 'cline_user_home'
      allow(Cline::Utils::Os).to receive(:user_home_dir).and_return mocked_user_home_dir
      @global_config_dir = "#{mocked_user_home_dir}/.cline"
      FileUtils.mkdir_p global_config_dir
    end

    # @return [String] The global config dir
    attr_reader :global_config_dir

    context 'when no skill is present' do
      it 'runs without any skill' do
        expect(capture_skills(skills: [])[:skills]).to eq({})
      end

      it 'fails when a skill is missing' do
        expect { capture_skills(skills: %w[unknown-skill]) }.to raise_error(
          ComposableAgents::Cline::MissingSkillError,
          'Cline Skill unknown-skill is unknown, neither in the global nor project configurations'
        )
      end
    end

    context 'when global skills are present' do
      before do
        create_skill(global_config_dir, 'test-skill-1')
        create_skill(global_config_dir, 'test-skill-2')
        create_skill(global_config_dir, 'test-skill-3')
      end

      it 'runs without any skill' do
        expect(capture_skills(skills: [])[:skills]).to eq({})
      end

      it 'fails when a skill is missing' do
        expect { capture_skills(skills: %w[unknown-skill]) }.to raise_error(
          ComposableAgents::Cline::MissingSkillError,
          'Cline Skill unknown-skill is unknown, neither in the global nor project configurations'
        )
      end

      it 'selects only needed skills' do
        skills_info = capture_skills(skills: %w[test-skill-1 test-skill-3])
        expect(skills_info[:skills]).to eq(
          {
            "#{skills_info[:config_dir]}/skills/test-skill-1/SKILL.md" => <<~EO_SKILL,
              ---
              name: test-skill-1
              description: Description
              ---

            EO_SKILL
            "#{skills_info[:config_dir]}/skills/test-skill-3/SKILL.md" => <<~EO_SKILL
              ---
              name: test-skill-3
              description: Description
              ---

            EO_SKILL
          }
        )
      end

      it 'copies all needed files' do
        create_skill(
          global_config_dir,
          'test-skill-with-files',
          extra_files: {
            'tools/save.rb' => '# Extra file content'
          }
        )
        skills_info = capture_skills(skills: %w[test-skill-with-files])
        expect(skills_info[:skills]).to eq(
          {
            "#{skills_info[:config_dir]}/skills/test-skill-with-files/SKILL.md" => <<~EO_SKILL,
              ---
              name: test-skill-with-files
              description: Description
              ---

            EO_SKILL
            "#{skills_info[:config_dir]}/skills/test-skill-with-files/tools/save.rb" => '# Extra file content'
          }
        )
      end

      it 'enables skills if needed' do
        create_skill(global_config_dir, 'test-skill-disabled', enabled: false)
        skills_info = capture_skills(skills: %w[test-skill-1 test-skill-disabled])
        expect(skills_info[:skills]).to eq(
          {
            "#{skills_info[:config_dir]}/skills/test-skill-1/SKILL.md" => <<~EO_SKILL,
              ---
              name: test-skill-1
              description: Description
              ---

            EO_SKILL
            "#{skills_info[:config_dir]}/skills/test-skill-disabled/SKILL.md" => <<~EO_SKILL
              ---
              name: test-skill-disabled
              description: Description
              ---

            EO_SKILL
          }
        )
      end

      it 'grabs dependent skills' do
        create_skill(
          global_config_dir,
          'test-skill-with-files',
          extra_files: {
            'tools/save.rb' => '# Extra file content'
          }
        )
        create_skill(global_config_dir, 'test-skill-with-deps', dependencies: %w[test-skill-1 test-skill-with-files])
        skills_info = capture_skills(skills: %w[test-skill-with-deps])
        expect(skills_info[:skills]).to eq(
          {
            "#{skills_info[:config_dir]}/skills/test-skill-1/SKILL.md" => <<~EO_SKILL,
              ---
              name: test-skill-1
              description: Description
              ---

            EO_SKILL
            "#{skills_info[:config_dir]}/skills/test-skill-with-files/SKILL.md" => <<~EO_SKILL,
              ---
              name: test-skill-with-files
              description: Description
              ---

            EO_SKILL
            "#{skills_info[:config_dir]}/skills/test-skill-with-files/tools/save.rb" => '# Extra file content',
            "#{skills_info[:config_dir]}/skills/test-skill-with-deps/SKILL.md" => <<~EO_SKILL
              ---
              name: test-skill-with-deps
              description: Description
              metadata:
                dependencies:
                - test-skill-1
                - test-skill-with-files
              ---

            EO_SKILL
          }
        )
      end

      it 'grabs nested dependent skills' do
        create_skill(global_config_dir, 'test-skill-with-deps-1', dependencies: %w[test-skill-with-deps-2])
        create_skill(global_config_dir, 'test-skill-with-deps-2', dependencies: %w[test-skill-1])
        skills_info = capture_skills(skills: %w[test-skill-with-deps-1])
        expect(skills_info[:skills]).to eq(
          {
            "#{skills_info[:config_dir]}/skills/test-skill-1/SKILL.md" => <<~EO_SKILL,
              ---
              name: test-skill-1
              description: Description
              ---

            EO_SKILL
            "#{skills_info[:config_dir]}/skills/test-skill-with-deps-1/SKILL.md" => <<~EO_SKILL,
              ---
              name: test-skill-with-deps-1
              description: Description
              metadata:
                dependencies:
                - test-skill-with-deps-2
              ---

            EO_SKILL
            "#{skills_info[:config_dir]}/skills/test-skill-with-deps-2/SKILL.md" => <<~EO_SKILL
              ---
              name: test-skill-with-deps-2
              description: Description
              metadata:
                dependencies:
                - test-skill-1
              ---

            EO_SKILL
          }
        )
      end

      it 'grabs diamond dependent skills' do
        create_skill(global_config_dir, 'test-skill-with-deps-1', dependencies: %w[test-skill-1])
        create_skill(global_config_dir, 'test-skill-with-deps-2', dependencies: %w[test-skill-1])
        skills_info = capture_skills(skills: %w[test-skill-with-deps-1 test-skill-with-deps-2])
        expect(skills_info[:skills]).to eq(
          {
            "#{skills_info[:config_dir]}/skills/test-skill-1/SKILL.md" => <<~EO_SKILL,
              ---
              name: test-skill-1
              description: Description
              ---

            EO_SKILL
            "#{skills_info[:config_dir]}/skills/test-skill-with-deps-1/SKILL.md" => <<~EO_SKILL,
              ---
              name: test-skill-with-deps-1
              description: Description
              metadata:
                dependencies:
                - test-skill-1
              ---

            EO_SKILL
            "#{skills_info[:config_dir]}/skills/test-skill-with-deps-2/SKILL.md" => <<~EO_SKILL
              ---
              name: test-skill-with-deps-2
              description: Description
              metadata:
                dependencies:
                - test-skill-1
              ---

            EO_SKILL
          }
        )
      end
    end

    context 'when project skills are present' do
      before do
        create_skill('.cline', 'test-skill-1')
        create_skill('.cline', 'test-skill-2')
        create_skill('.cline', 'test-skill-3')
      end

      it 'disables all skills if run without any skill' do
        expect(capture_skills(skills: [])[:skills]).to eq(
          {
            '.cline/skills/test-skill-1/SKILL.md' => <<~EO_SKILL,
              ---
              name: test-skill-1
              description: Description
              disabled: true
              ---

            EO_SKILL
            '.cline/skills/test-skill-2/SKILL.md' => <<~EO_SKILL,
              ---
              name: test-skill-2
              description: Description
              disabled: true
              ---

            EO_SKILL
            '.cline/skills/test-skill-3/SKILL.md' => <<~EO_SKILL
              ---
              name: test-skill-3
              description: Description
              disabled: true
              ---

            EO_SKILL
          }
        )
      end

      it 'fails when a skill is missing' do
        expect { capture_skills(skills: %w[unknown-skill]) }.to raise_error(
          ComposableAgents::Cline::MissingSkillError,
          'Cline Skill unknown-skill is unknown, neither in the global nor project configurations'
        )
      end

      it 'enables only needed skills' do
        skills_info = capture_skills(skills: %w[test-skill-1 test-skill-3])
        expect(skills_info[:skills]).to eq(
          {
            '.cline/skills/test-skill-1/SKILL.md' => <<~EO_SKILL,
              ---
              name: test-skill-1
              description: Description
              ---

            EO_SKILL
            '.cline/skills/test-skill-2/SKILL.md' => <<~EO_SKILL,
              ---
              name: test-skill-2
              description: Description
              disabled: true
              ---

            EO_SKILL
            '.cline/skills/test-skill-3/SKILL.md' => <<~EO_SKILL
              ---
              name: test-skill-3
              description: Description
              ---

            EO_SKILL
          }
        )
      end

      it 'enables skills if needed' do
        create_skill('.cline', 'test-skill-disabled', enabled: false)
        skills_info = capture_skills(skills: %w[test-skill-1 test-skill-disabled])
        expect(skills_info[:skills]).to eq(
          {
            '.cline/skills/test-skill-disabled/SKILL.md' => <<~EO_SKILL,
              ---
              name: test-skill-disabled
              description: Description
              ---

            EO_SKILL
            '.cline/skills/test-skill-1/SKILL.md' => <<~EO_SKILL,
              ---
              name: test-skill-1
              description: Description
              ---

            EO_SKILL
            '.cline/skills/test-skill-2/SKILL.md' => <<~EO_SKILL,
              ---
              name: test-skill-2
              description: Description
              disabled: true
              ---

            EO_SKILL
            '.cline/skills/test-skill-3/SKILL.md' => <<~EO_SKILL
              ---
              name: test-skill-3
              description: Description
              disabled: true
              ---

            EO_SKILL
          }
        )
      end

      it 'enables dependent skills' do
        create_skill('.cline', 'test-skill-with-deps', dependencies: %w[test-skill-1 test-skill-3])
        skills_info = capture_skills(skills: %w[test-skill-with-deps])
        expect(skills_info[:skills]).to eq(
          {
            '.cline/skills/test-skill-with-deps/SKILL.md' => <<~EO_SKILL,
              ---
              name: test-skill-with-deps
              description: Description
              metadata:
                dependencies:
                - test-skill-1
                - test-skill-3
              ---

            EO_SKILL
            '.cline/skills/test-skill-1/SKILL.md' => <<~EO_SKILL,
              ---
              name: test-skill-1
              description: Description
              ---

            EO_SKILL
            '.cline/skills/test-skill-2/SKILL.md' => <<~EO_SKILL,
              ---
              name: test-skill-2
              description: Description
              disabled: true
              ---

            EO_SKILL
            '.cline/skills/test-skill-3/SKILL.md' => <<~EO_SKILL
              ---
              name: test-skill-3
              description: Description
              ---

            EO_SKILL
          }
        )
      end

      it 'enables nested dependent skills' do
        create_skill('.cline', 'test-skill-with-deps-1', dependencies: %w[test-skill-with-deps-2])
        create_skill('.cline', 'test-skill-with-deps-2', dependencies: %w[test-skill-1])
        skills_info = capture_skills(skills: %w[test-skill-with-deps-1])
        expect(skills_info[:skills]).to eq(
          {
            '.cline/skills/test-skill-with-deps-1/SKILL.md' => <<~EO_SKILL,
              ---
              name: test-skill-with-deps-1
              description: Description
              metadata:
                dependencies:
                - test-skill-with-deps-2
              ---

            EO_SKILL
            '.cline/skills/test-skill-with-deps-2/SKILL.md' => <<~EO_SKILL,
              ---
              name: test-skill-with-deps-2
              description: Description
              metadata:
                dependencies:
                - test-skill-1
              ---

            EO_SKILL
            '.cline/skills/test-skill-1/SKILL.md' => <<~EO_SKILL,
              ---
              name: test-skill-1
              description: Description
              ---

            EO_SKILL
            '.cline/skills/test-skill-2/SKILL.md' => <<~EO_SKILL,
              ---
              name: test-skill-2
              description: Description
              disabled: true
              ---

            EO_SKILL
            '.cline/skills/test-skill-3/SKILL.md' => <<~EO_SKILL
              ---
              name: test-skill-3
              description: Description
              disabled: true
              ---

            EO_SKILL
          }
        )
      end

      it 'enables diamond dependent skills' do
        create_skill('.cline', 'test-skill-with-deps-1', dependencies: %w[test-skill-1])
        create_skill('.cline', 'test-skill-with-deps-2', dependencies: %w[test-skill-1])
        skills_info = capture_skills(skills: %w[test-skill-with-deps-1 test-skill-with-deps-2])
        expect(skills_info[:skills]).to eq(
          {
            '.cline/skills/test-skill-with-deps-1/SKILL.md' => <<~EO_SKILL,
              ---
              name: test-skill-with-deps-1
              description: Description
              metadata:
                dependencies:
                - test-skill-1
              ---

            EO_SKILL
            '.cline/skills/test-skill-with-deps-2/SKILL.md' => <<~EO_SKILL,
              ---
              name: test-skill-with-deps-2
              description: Description
              metadata:
                dependencies:
                - test-skill-1
              ---

            EO_SKILL
            '.cline/skills/test-skill-1/SKILL.md' => <<~EO_SKILL,
              ---
              name: test-skill-1
              description: Description
              ---

            EO_SKILL
            '.cline/skills/test-skill-2/SKILL.md' => <<~EO_SKILL,
              ---
              name: test-skill-2
              description: Description
              disabled: true
              ---

            EO_SKILL
            '.cline/skills/test-skill-3/SKILL.md' => <<~EO_SKILL
              ---
              name: test-skill-3
              description: Description
              disabled: true
              ---

            EO_SKILL
          }
        )
      end
    end

    context 'when both global and project skills are present' do
      before do
        create_skill(global_config_dir, 'global-skill-1')
        create_skill(global_config_dir, 'global-skill-2')
        create_skill('.cline', 'project-skill-1')
        create_skill('.cline', 'project-skill-2')
      end

      it 'enables project dependent skills that are global dependencies' do
        create_skill(global_config_dir, 'global-skill-with-deps', dependencies: %w[project-skill-1])
        skills_info = capture_skills(skills: %w[global-skill-with-deps])
        expect(skills_info[:skills]).to eq(
          {
            "#{skills_info[:config_dir]}/skills/global-skill-with-deps/SKILL.md" => <<~EO_SKILL,
              ---
              name: global-skill-with-deps
              description: Description
              metadata:
                dependencies:
                - project-skill-1
              ---

            EO_SKILL
            '.cline/skills/project-skill-1/SKILL.md' => <<~EO_SKILL,
              ---
              name: project-skill-1
              description: Description
              ---

            EO_SKILL
            '.cline/skills/project-skill-2/SKILL.md' => <<~EO_SKILL
              ---
              name: project-skill-2
              description: Description
              disabled: true
              ---

            EO_SKILL
          }
        )
      end

      it 'grabs global dependent skills that are project dependencies' do
        create_skill('.cline', 'project-skill-with-deps', dependencies: %w[global-skill-1])
        skills_info = capture_skills(skills: %w[project-skill-with-deps])
        expect(skills_info[:skills]).to eq(
          {
            '.cline/skills/project-skill-with-deps/SKILL.md' => <<~EO_SKILL,
              ---
              name: project-skill-with-deps
              description: Description
              metadata:
                dependencies:
                - global-skill-1
              ---

            EO_SKILL
            "#{skills_info[:config_dir]}/skills/global-skill-1/SKILL.md" => <<~EO_SKILL,
              ---
              name: global-skill-1
              description: Description
              ---

            EO_SKILL
            '.cline/skills/project-skill-1/SKILL.md' => <<~EO_SKILL,
              ---
              name: project-skill-1
              description: Description
              disabled: true
              ---

            EO_SKILL
            '.cline/skills/project-skill-2/SKILL.md' => <<~EO_SKILL
              ---
              name: project-skill-2
              description: Description
              disabled: true
              ---

            EO_SKILL
          }
        )
      end

      it 'enables and grabs nested dependent skills' do
        create_skill('.cline', 'project-skill-with-deps-1', dependencies: %w[global-skill-with-deps-2])
        create_skill(global_config_dir, 'global-skill-with-deps-2', dependencies: %w[project-skill-with-deps-3])
        create_skill('.cline', 'project-skill-with-deps-3', dependencies: %w[global-skill-1])
        skills_info = capture_skills(skills: %w[project-skill-with-deps-1])
        expect(skills_info[:skills]).to eq(
          {
            '.cline/skills/project-skill-with-deps-1/SKILL.md' => <<~EO_SKILL,
              ---
              name: project-skill-with-deps-1
              description: Description
              metadata:
                dependencies:
                - global-skill-with-deps-2
              ---

            EO_SKILL
            "#{skills_info[:config_dir]}/skills/global-skill-with-deps-2/SKILL.md" => <<~EO_SKILL,
              ---
              name: global-skill-with-deps-2
              description: Description
              metadata:
                dependencies:
                - project-skill-with-deps-3
              ---

            EO_SKILL
            '.cline/skills/project-skill-with-deps-3/SKILL.md' => <<~EO_SKILL,
              ---
              name: project-skill-with-deps-3
              description: Description
              metadata:
                dependencies:
                - global-skill-1
              ---

            EO_SKILL
            "#{skills_info[:config_dir]}/skills/global-skill-1/SKILL.md" => <<~EO_SKILL,
              ---
              name: global-skill-1
              description: Description
              ---

            EO_SKILL
            '.cline/skills/project-skill-1/SKILL.md' => <<~EO_SKILL,
              ---
              name: project-skill-1
              description: Description
              disabled: true
              ---

            EO_SKILL
            '.cline/skills/project-skill-2/SKILL.md' => <<~EO_SKILL
              ---
              name: project-skill-2
              description: Description
              disabled: true
              ---

            EO_SKILL
          }
        )
      end

      it 'enables diamond dependent skills' do
        create_skill('.cline', 'project-skill-with-deps-1', dependencies: %w[project-skill-1])
        create_skill(global_config_dir, 'global-skill-with-deps-2', dependencies: %w[project-skill-1])
        skills_info = capture_skills(skills: %w[project-skill-with-deps-1 global-skill-with-deps-2])
        expect(skills_info[:skills]).to eq(
          {
            '.cline/skills/project-skill-with-deps-1/SKILL.md' => <<~EO_SKILL,
              ---
              name: project-skill-with-deps-1
              description: Description
              metadata:
                dependencies:
                - project-skill-1
              ---

            EO_SKILL
            "#{skills_info[:config_dir]}/skills/global-skill-with-deps-2/SKILL.md" => <<~EO_SKILL,
              ---
              name: global-skill-with-deps-2
              description: Description
              metadata:
                dependencies:
                - project-skill-1
              ---

            EO_SKILL
            '.cline/skills/project-skill-1/SKILL.md' => <<~EO_SKILL,
              ---
              name: project-skill-1
              description: Description
              ---

            EO_SKILL
            '.cline/skills/project-skill-2/SKILL.md' => <<~EO_SKILL
              ---
              name: project-skill-2
              description: Description
              disabled: true
              ---

            EO_SKILL
          }
        )
      end
    end
  end
end
