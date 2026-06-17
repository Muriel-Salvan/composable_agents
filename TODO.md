* Cline: the instructions given should be part of the first user prompt only, otherwise the agent repeats those instructions every time the user asks something else in the same context.
* Fix yard documentation (Hash<Symbol, Object>, NilClass, Public API groups).
* README.rb.
* Check Rubocop-rspec exceptions and try to remove them.
* Check that yard is used correctly everywhere and check how to see corresponding generated doc.
* Add agents manifesto for contributors.
* Add an Agent helper to review an artifact (with potential user modification of it).
* Add some info logging (not debug) that would allow detecting when infinite loops or blocked agents occur.
