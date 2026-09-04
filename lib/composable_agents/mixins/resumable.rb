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
    # This mixin uses the following methods from the agent:
    # - `#export_state -> Object` Optional method returning the current JSON-serializable state of the agent.
    # - `#import_state(state)` Optional method that sets the agent state from a JSON-serializable object.
    #
    # This mixin publishes the following run information:
    # - steps [Array<Hash>>] Hierarchy of the steps executed during the run.
    #   Each step node has those properties:
    #   - step_name [Symbol] The step name.
    #   - index [Array<Integer>] Position of the step in the hierarchy of recursive step calls.
    #     It is the succession of indices from the root of the hierarchy to this step node,
    #     each index being the position of the node among its sibling nodes (children of the same parent).
    #     For example here are the values of the index property of the step nodes if we have this code:
    #     # index == [0]
    #     step(:a) do
    #       # index == [0, 0]
    #       step(:a1) do
    #         # index == [0, 0, 0]
    #       end
    #       # index == [0, 1]
    #       step(:a2) do
    #         # index == [0, 1, 0]
    #         step(:a21) do
    #           # index == [0, 1, 0, 0]
    #         end
    #         # index == [0, 1, 1]
    #         step(:a22) do
    #           # index == [0, 1, 1, 0]
    #         end
    #         # index == [0, 1, 2]
    #       end
    #       # index == [0, 2]
    #     end
    #     # index == [1]
    #     step(:b) do
    #       # index == [1, 0]
    #     end
    #   - status [Symbol] The status of the step:
    #     - `started``: The step has started its execution.
    #     - `cached``: The step was skipped because of a previous execution.
    #     - `executed``: The step has completed its execution.
    #     - `error``: The step has raised an exception during its execution.
    #   - created_at [Time] Timestamp of the creation of this step node.
    #   - extra_input_artifacts [Hash] Additional artifacts given as input to this step.
    #   - agent [Agent, nil] The agent that is invoked in this step, or nil if none.
    #   - error [String, nil] The message of the exception raised during the step execution.
    #     This property is only present when the status is `error`.
    #   - children [Array<Hash>] Sub-steps that are invoked from this step.
    module Resumable
      # @!group Public API

      # Constructor
      #
      # @param run_id [String, nil] ID identifying this run to reuse previously executed steps, or nil if there is no resumability needed
      def initialize(*args, run_id: nil, **kwargs)
        super(*args, **kwargs)
        @run_id = run_id
      end

      # @!group Internal

      # Execute the agent to generate some output artifacts based on some input artifacts.
      #
      # @param input_artifacts [Hash{Symbol => Object}] The input artifacts content, per artifact name
      # @return [Hash{Symbol => Object}] The output artifacts returned by the Proc
      def run(**input_artifacts)
        # The artifacts store, JSON serializable
        @artifacts = input_artifacts.dup
        @current_run_steps = []
        @current_step_node = nil
        super
      end

      private

      # Define a step that can be serialized and resumed.
      # This will store the state of this step in the file system.
      # If this step was already executed, skip it and update its artifacts from the file system store.
      #
      # @param step_name [Symbol] Step name.
      # @param kwargs [Hash{Symbol => Object}] Additional input artifacts to merge before the step executes.
      # @yield The code called for this step
      def step(step_name = :step, **kwargs, &)
        internal_step(step_name:, agent: nil, extra_input_artifacts: kwargs, &)
      end

      # Define a step that will just run an agent.
      # This will use the artifacts store for input and output artifacts.
      # Handle the context of the agent if needed.
      #
      # @param agent [Agent] The agent to run.
      # @param kwargs [Hash{Symbol => Object}] Additional input artifacts to merge before the step executes.
      def step_agent(agent, **kwargs)
        internal_step(step_name: :"agent_run_#{(agent.name || 'unnamed').gsub(/[^\w]/, '_')}", agent:, extra_input_artifacts: kwargs) do
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
      # @param step_name [Symbol] Step name.
      # @param agent [Agent, nil] Agent that is used in this step, or nil if none.
      # @param extra_input_artifacts [Hash{Symbol => Object}] Additional input artifacts to merge before the step executes.
      # @yield The code called for this step
      def internal_step(step_name:, agent:, extra_input_artifacts: {})
        record_step(step_name:, agent:, extra_input_artifacts:) do
          @artifacts.merge!(extra_input_artifacts)
          if @run_id.nil?
            yield
            @current_step_node[:status] = :executed
          else
            # Compute the current step state
            step_state = current_step_state(agent:)
            # Read the persisted step state if any
            step_full_name = "#{@current_step_node[:index].join('-')}-#{step_name}"
            saved_input_state, saved_output_state = saved_step_states(step_full_name)
            # If the input exists, it means the step was already executed.
            # If it is the same state as the current one, skip the step and set the current state to the stored output step state.
            if step_state == saved_input_state
              @current_step_node[:status] = :cached
              set_current_step_state(saved_output_state, agent:)
              log_debug "[Step #{step_full_name}] - Already executed - Got #{@artifacts.size} artifacts from persistence: #{@artifacts.keys.join(', ')}"
            else
              # Clone state before yielding because it will certainly be modified
              input_step_state = clone_step_state(step_state)
              yield
              @current_step_node[:status] = :executed
              store_step_states(step_full_name, input: input_step_state, output: current_step_state(agent:))
              log_debug "[Step #{step_full_name}] - Executed - Stored #{@artifacts.size} artifacts in persistence: #{@artifacts.keys.join(', ')}"
            end
          end
        end
      end

      # Record a step node in the steps hierarchy, then execute the step's code.
      # Steps executed while this node is the current one are recorded as its children.
      #
      # @param step_name [Symbol] Name of the step, mirroring the one used by the persisted steps.
      # @param agent [ComposableAgents::Agent, nil] The agent run by this step, or nil for plain steps.
      # @param extra_input_artifacts [Hash{Symbol => Object}] Input artifacts given to the step.
      # @yield The code of the step to be executed
      def record_step(step_name:, agent:, extra_input_artifacts:)
        publish_run_info(steps: @current_run_steps) unless current_run_info.respond_to?(:steps)
        parent_node = @current_step_node
        node = {
          step_name:,
          # Compute the index of this step in the hierarchy of recursive step calls:
          # the indices of the ancestor step nodes, followed by this node's position among its sibling nodes.
          index: (parent_node ? parent_node[:index] : []) + [(parent_node ? parent_node[:children] : @current_run_steps).size],
          status: :started,
          created_at: Time.now,
          agent:,
          extra_input_artifacts: extra_input_artifacts.clone,
          children: []
        }
        if parent_node
          parent_node[:children] << node
        else
          @current_run_steps << node
        end
        @current_step_node = node
        begin
          yield
        rescue Exception => e # rubocop:disable Lint/RescueException -- Record the error status of any failing step, including Ctrl-C interruptions (Interrupt)
          node[:status] = :error
          node[:error] = e.message
          raise
        end
      ensure
        @current_step_node = parent_node
      end

      # Get the current step state.
      #
      # @param agent [Agent, nil] Agent that is used in this step, or nil if none.
      # @return [Hash{Symbol => Object}] The current step state
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
      # @return [Array<Hash{Symbol => Object}, nil>] The saved step states:
      #   0. [Hash{Symbol => Object}, nil] The input step state or nil if none
      #   1. [Hash{Symbol => Object}, nil] The output step state or nil if none
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
      # @param input [Hash{Symbol => Object}] The input step state
      # @param output [Hash{Symbol => Object}] The output step state
      def store_step_states(step_full_name, input:, output:)
        step_json_file = saved_step_states_json(step_full_name)
        FileUtils.mkdir_p(File.dirname(step_json_file))
        File.write(
          step_json_file,
          JSON.dump(
            {
              input:,
              output:
            }
          )
        )
      end

      # Set the current state to a given step state
      #
      # @param step_state [Hash{Symbol => Object}] The step state to use
      # @param agent [Agent, nil] Agent that is used in this step, or nil if none.
      def set_current_step_state(step_state, agent:)
        @artifacts = step_state[:artifacts]
        agent.import_state(step_state[:agent_state]) if !agent.nil? && agent.respond_to?(:import_state)
      end

      # Clone a step state.
      #
      # @param step_state [Hash{Symbol => Object}] Step state to be cloned
      # @return [Hash{Symbol => Object}] Cloned step state
      def clone_step_state(step_state)
        cloned_step_state = {
          artifacts: step_state[:artifacts].dup
        }
        # Perform a deep clone using JSON
        cloned_step_state[:agent_state] = JSON.parse(JSON.dump(step_state[:agent_state])) if step_state.key?(:agent_state)
        cloned_step_state
      end
    end
  end
end
