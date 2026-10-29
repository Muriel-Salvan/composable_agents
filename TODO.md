* Add the Retriable mixin to Cline::Agent with proper methods or config to define fallback models or changes in case of errors, with exponential waits.
* Use the Retriable mixin with ArtifactContract.
* Add a way to detect infinite loops in agents and act on it (maybe a mixin looking at prompts/messages).
* Add a way to kill an agent run on a given timeout (generic mixin).
* Check Rubocop-rspec exceptions and try to remove them.
* Add agents manifesto for contributors.
* Add some info logging (not debug) that would allow detecting when infinite loops or blocked agents occur.
* Make tests run faster.
