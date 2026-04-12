require 'json'
require 'fileutils'

module ComposableAgents
  module Mixins
    # Mixin adding resumable step capabilities to agents.
    # An agent prepending this mixin can use the following:
    # * A new constructor named parameter run_id that identifies the run that can be resumable.
    # * A step re-entrant method that defines a part of the agent's processing whose input/output is persisted
    #   and that can be skipped if it was previously executed.
    # * An instance variable @artifacts that stores artifacts (initialized with input ones) that are JSON serialized by steps.
    # Artifacts used with this mixin should be JSON-serializable.
    module Resumable
      # Constructor
      #
      # @param run_id [String, NilClass] ID identifying this run to reuse previously executed steps, or nil if there is no resumability needed
      def initialize(*args, run_id: nil, **kwargs)
        super(*args, **kwargs)
        @run_id = run_id
      end

      # Execute the agent by calling the wrapped Proc
      #
      # @param input_artifacts [Hash<Symbol,Object>] The input artifacts content, per artifact name
      # @return [Hash<Symbol,Object>] The output artifacts returned by the Proc
      def run(input_artifacts: {})
        # The artifacts store, JSON serializable
        @artifacts = input_artifacts.dup
        # List of the levels' next step index, following the hierarchy of recusive step calls.
        # This is only used if there is a persistent run ID.
        # For example here are the values of this variable if we have this code:
        # # @steps_idx == [0]
        # step(:a) do
        #   # @steps_idx == [0, 0]
        #   step(:a1) do
        #     # @steps_idx == [0, 0, 0]
        #   end
        #   # @steps_idx == [0, 1]
        #   step(:a2) do
        #     # @steps_idx == [0, 1, 0]
        #     step(:a21) do
        #       # @steps_idx == [0, 1, 0, 0]
        #     end
        #     # @steps_idx == [0, 1, 1]
        #     step(:a22) do
        #       # @steps_idx == [0, 1, 1, 0]
        #     end
        #     # @steps_idx == [0, 1, 2]
        #   end
        #   # @steps_idx == [0, 2]
        # end
        # # @steps_idx == [1]
        # step(:b) do
        #   # @steps_idx == [1, 0]
        # end
        @steps_idx = [0] unless @run_id.nil?
        super
      end

      private

      # Define a step that can be serialized and resumed.
      # This will store the state of this step in the file system.
      # If this step was already executed, skip it and update its artifacts from the file system store.
      #
      # @param name [Symbol] Step name.
      # @yield The code called for this step
      def step(name = :step)
        if @run_id.nil?
          yield
        else
          full_name = "#{@steps_idx.join('-')}-#{name}"
          step_json_file = "#{@composable_agents_dir}/runs/#{@run_id}/#{full_name}.json"
          # If the file exists, it means the step was already executed.
          # Check the artifacts it got from this step.
          # If they are the same ones as the current ones, skip the step and set the artifacts to the step's output artifacts.
          step_info = File.exist?(step_json_file) ? JSON.parse(File.read(step_json_file), symbolize_names: true) : {}
          if @artifacts == step_info[:input_artifacts]
            @artifacts = step_info[:output_artifacts]
            log_debug "[Step #{full_name}] - Already executed - Got #{@artifacts.size} from persistence: #{@artifacts.keys.join(', ')}"
          else
            input_artifacts = @artifacts.dup
            @steps_idx << 0
            yield
            @steps_idx.pop
            FileUtils.mkdir_p(File.dirname(step_json_file))
            File.write(
              step_json_file,
              {
                input_artifacts:,
                output_artifacts: @artifacts
              }.to_json
            )
            log_debug "[Step #{full_name}] - Executed - Stored #{@artifacts.size} artifacts in persistence: #{@artifacts.keys.join(', ')}"
          end
          @steps_idx[-1] += 1
        end
      end
    end
  end
end
