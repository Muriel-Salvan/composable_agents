* Add a new mixin for Cline::Agent with proper methods or config to define retries in case of errors, with exponential waits.
* Add a new retry mixin for Cline::Agent with proper methods or config to define retries in case of errors and 429 issues to define fallback models in case of errors, with exponential waits (reuse code from the RetriableCline mixin).
* Add a way to detect infinite loops in agents and act on it (maybe a mixin looking at prompts/messages).
* Add a way to kill an agent run on a given timeout (generic mixin).
* Check Rubocop-rspec exceptions and try to remove them.
* Add agents manifesto for contributors.
* Add some info logging (not debug) that would allow detecting when infinite loops or blocked agents occur.
* Make tests run faster.
