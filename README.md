# IsoLatte

Sometimes you need to run background jobs that you can't make important
guarantees about - they may run out of memory and get killed, or produce
segmentation faults, or `exit!` directly - and you need to be able to clean
up after such problems.

IsoLatte is a gem that allows a block of code to be executed in a subprocess.
Exceptions get passed back to the parent process through a pipe, and various
exit conditions are handled via configurable callbacks.

## Simple Process Isolation

```ruby
IsoLatte.fork do
  do_something_crazy!
end
```

`do_something_crazy!` is now being invoked in a forked subprocess - if it
crashes the interpreter, or gets killed by the OS, instead of taking down
the original process, it will invoke the appropriate callback in the parent.

## Complex Example

```ruby
IsoLatte.fork(
  stderr:   "/tmp/suberr.txt",
  finish:   ->(success, rc) { warn "Finished. Success? #{success}" },
  success:  ->() { warn "Was successful" },
  kill:     ->() { warn "Received a SIGKILL" },
  fault:    ->() { warn "Received a SIGABRT, probably a segmentation fault" },
  exit:     ->(rc) { warn "subprocess exited explicitly with #{rc}" }
) { do_something_crazy! }
```

### Options

* `stderr` - A path to write the subprocess' stderr stream into. Defaults to '/dev/null',
              supplying `nil` lets the subprocess continue writing to the parent's stderr stream.
* `success` - a callable to execute if the subprocess completes successfully.
* `fault`   - a callable to execute if the subprocess receives a SIGABRT (segfault).
* `kill`    - a callable to execute if the subprocess receives a SIGKILL (from `kill -9` or oom-killer)
* `exit`    - a callable to execute if the subprocess explicitly exits with nonzero status.
              Receives the exit status value as its argument.
* `finish`  - a callable to execute when the subprocess terminates in any way. It receives
               a boolean 'success' value and an exit status as its arguments.
* `timeout` - a number of seconds to wait - if the process has not terminated by then,
              the parent will kill it by issuing a SIGKILL signal (triggering the kill callback)

## Roadmap

1. Add a convenient mechanism for sending a single marshaled object back to the parent afterward.
2. Allow the `stderr` to accept a callback to call for each line instead.
3. Improve compatibility with various gems that modify Exception, like `better_errors`.
