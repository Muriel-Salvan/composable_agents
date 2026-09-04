module ComposableAgents
  # Store runtime information about a run
  class RunInfo
    # Constructor
    def initialize
      @properties = {}
    end

    # Publish properties
    #
    # @param kwargs [Hash{Symbol => Object}] Set of properties to publish
    def publish(**kwargs)
      kwargs.each do |name, value|
        @properties[name] = value
        singleton_class.define_method(name) { @properties.fetch(name) } unless singleton_class.respond_to?(name)
      end
    end
  end
end
