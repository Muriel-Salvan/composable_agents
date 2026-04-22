require 'json'
require 'fileutils'

module ComposableAgents
  module Mixins
    # Mixin adding resumable step capabilities to agents.
    # An agent prepending this mixin can use the following:
    # * A new constructor named parameter run_id that identifies the run that can be resumable.
    # * A step re-entrant method that defines a part of the agent's processing whose input/output is persisted
    #   and that can be skipped if it was previously executed.
    # * An agent_step method that calls a sub-agent with the artifacts and also tracks the state of this agent.
    #   * Any agent that implements the methods export_state and import_state will benefit from its state's serialization automatically.
    # * An instance variable @artifacts that stores artifacts (initialized with input ones) that are JSON serialized by steps.
    # Artifacts used with this mixin, and states returned by used agents should be JSON-serializable.
    module Resumable
      # Constructor
      #
      # @param run_id [String, NilClass] ID identifying this run to reuse previously executed steps, or nil if there is no resumability needed
      def initialize(*args, run_id: nil, **kwargs)
        super(*args, **kwargs)
        @run_id = run_id
      end

      # Execute the agent to generate some output artifacts based on some input artifacts.
      #
      # @param input_artifacts [Hash<Symbol,Object>] The input artifacts content, per artifact name
      # @return [Hash<Symbol,Object>] The output artifacts returned by the Proc
      def run(**input_artifacts)
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
      # @yieldparam step_full_name [String, NilClass] The step full name, as a unique identifier, or nil if no run ID
      def step(name = :step, &)
        internal_step(name:, agent: nil, &)
      end

      # Define a step that will just run an agent.
      # This will use the artifacts store for input and output artifacts.
      # Handle the context of the agent if needed.
      #
      # @param agent [Agent] The agent to run.
      def step_agent(agent)
        internal_step(name: :"agent_run_#{agent.name}", agent:) do
          @artifacts.merge!(agent.run(**@artifacts))
        end
      end

      # Below methods are not supposed to be used directly by the mixin user.
      # They are only internals.

      # Define a step that can be serialized and resumed.
      # This will store the state of this step in the file system.
      # If this step was already executed, skip it and update its artifacts from the file system store.
      # Handle the state of an optional agent in the case this step is executed for an agent.
      # This method should not be used directly.
      #
      # @param name [Symbol] Step name.
      # @param agent [Agent, NilClass] Agent that is used in this step, or nil if none.
      # @yield The code called for this step
      def internal_step(name:, agent:)
        if @run_id.nil?
          yield
        else
          # Compute the current step state
          step_state = current_step_state(agent:)
          # Read the persisted step state if any
          full_name = "#{@steps_idx.join('-')}-#{name}"
          saved_input_state, saved_output_state = saved_step_states(full_name)
          # If the input exists, it means the step was already executed.
          # If it is the same state as the current one, skip the step and set the current state to the stored output step state.
          if step_state == saved_input_state
            set_current_step_state(saved_output_state, agent:)
            log_debug "[Step #{full_name}] - Already executed - Got #{@artifacts.size} from persistence: #{@artifacts.keys.join(', ')}"
          else
            # Clone state before yielding because it will certainly be modified
            input_step_state = clone_step_state(step_state)
            @steps_idx << 0
            yield
            @steps_idx.pop
            store_step_states(full_name, input: input_step_state, output: current_step_state(agent:))
            log_debug "[Step #{full_name}] - Executed - Stored #{@artifacts.size} artifacts in persistence: #{@artifacts.keys.join(', ')}"
          end
          @steps_idx[-1] += 1
        end
      end

      # Get the current step state.
      #
      # @param agent [Agent, NilClass] Agent that is used in this step, or nil if none.
      # @return [Hash<Symbol, Object>] The current step state
      def current_step_state(agent:)
        step_state = {
          artifacts: @artifacts
        }
        step_state[:agent_state] = agent.export_state if !agent.nil? && agent.respond_to?(:export_state)
        step_state
      end

      # Get saved step states JSON file for a given full step name.
      #
      # @param step_full_name [String] Step full name
      # @return [String] Corresponding JSON file that stores the step states
      def saved_step_states_json(step_full_name)
        "#{@composable_agents_dir}/runs/#{@run_id}/#{step_full_name.gsub(/[^\w.]/, '_')}.json"
      end

      # Get saved step states from a given full step name.
      # This will read the step states from the persistence layer.
      #
      # @param step_full_name [String] Step full name
      # @return [Array<Hash<Symbol, Object>, NilClass>] The saved step states:
      #   0. [Hash<Symbol, Object>, NilClass] The input step state or nil if none
      #   1. [Hash<Symbol, Object>, NilClass] The output step state or nil if none
      def saved_step_states(step_full_name)
        step_json_file = saved_step_states_json(step_full_name)
        step_info = File.exist?(step_json_file) ? JSON.parse(File.read(step_json_file)).transform_keys(&:to_sym) : {}
        step_info[:input]&.transform_keys!(&:to_sym)
        step_info.dig(:input, :artifacts)&.transform_keys!(&:to_sym)
        step_info[:output]&.transform_keys!(&:to_sym)
        step_info.dig(:output, :artifacts)&.transform_keys!(&:to_sym)
        [step_info[:input], step_info[:output]]
      end

      # Store step states for a given full step name in the persistence layer.
      #
      # @param step_full_name [String] Step full name
      # @param input [Hash<Symbol, Object>] The input step state
      # @param output [Hash<Symbol, Object>] The output step state
      def store_step_states(step_full_name, input:, output:)
        step_json_file = saved_step_states_json(step_full_name)
        FileUtils.mkdir_p(File.dirname(step_json_file))
        File.write(
          step_json_file,
          {
            input:,
            output:
          }.to_json
        )
      end

      # Set the current state to a given step state
      #
      # @param step_state [Hash<Symbol, Object>] The step state to use
      # @param agent [Agent, NilClass] Agent that is used in this step, or nil if none.
      def set_current_step_state(step_state, agent:)
        @artifacts = step_state[:artifacts]
        agent.import_state(step_state[:agent_state]) if !agent.nil? && agent.respond_to?(:import_state)
      end

      # Clone a step state.
      #
      # @param step_state [Hash<Symbol, Object>] Step state to be cloned
      # @return [Hash<Symbol, Object>] Cloned step state
      def clone_step_state(step_state)
        cloned_step_state = {
          artifacts: step_state[:artifacts].dup
        }
        cloned_step_state[:agent_state] = step_state[:agent_state].dup if step_state.key?(:agent_state)
        cloned_step_state
      end
    end
  end
end
