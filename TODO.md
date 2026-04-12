* README.rb.
* Make artifacts validation a mixin, and make safe_run the normal run. Add tests of subclasses adding more artifacts to the lists.
* Check Rubocop-rspec exceptions and try to remove them.
* Resumable test scenarios:
  * Is not resumable if run_id is nil
  * Steps can be called inside steps and resume exactly where it has left off
  * Artifacts are persisted and retrieved correctly, for any JSON kind
  * Steps are reexecuted when artifacts change
  * Name defaulting to the caller
  * With and without run_id in artifacts
  * Steps are being resumed when artifacts are the same ones
  * Resuming restores artifacts at each step
  * run_id should default to the agent name?
* Check that yard is used correctly everywhere and check how to see corresponding generated doc.
