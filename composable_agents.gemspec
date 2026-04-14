require_relative 'lib/composable_agents/version'

Gem::Specification.new do |spec|
  spec.name          = 'composable_agents'
  spec.version       = ComposableAgents::VERSION
  spec.summary       = 'Composable AI agents framework'
  spec.homepage      = 'https://github.com/Muriel-Salvan/composable_agents'
  spec.license       = 'BSD-3-Clause'

  spec.author        = 'Muriel Salvan'
  spec.email         = 'muriel@x-aeon.com'

  spec.files         = Dir['*.{md,txt}', '{lib}/**/*']
  spec.executables   = Dir['bin/*'].map { |exe_file| File.basename(exe_file) }
  spec.require_path  = 'lib'

  spec.required_ruby_version = '>= 3.1'

  spec.add_dependency 'ai-agents', '~> 0.9'
  spec.add_dependency 'zeitwerk', '~> 2.7'

  spec.metadata['rubygems_mfa_required'] = 'true'
end
