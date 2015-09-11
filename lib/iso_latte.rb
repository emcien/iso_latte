require "ostruct"
require "timeout"

module IsoLatte
  NO_EXIT = 122
  EXCEPTION_RAISED = 123

  # Available options:
  #   stderr:   a path to write stderr into. Defaults to '/dev/null'
  #             nil means "do not change stderr"
  #   finish:   a callable to execute when the subprocess terminates (in any way).
  #             receives a boolean 'success' value, and an exitstatus as arguments
  #   success:  a callable to execute if the subprocess completes successfully.
  #             note: this can exit ALONGSIDE the exit callback, if the subprocess
  #             exits with zero explicitly!
  #   kill:     a callable to execute if the subprocess is killed (SIGKILL).
  #   fault:    a callable to execute if the subprocess segfaults, core dumps, etc.
  #   exit:     a callable to execute if the subprocess voluntarily exits with nonzero.
  #             receives the exit status value as its argument.
  #   timeout:  after this many seconds, the parent should send a SIGKILL to the child.
  #
  # It is allowable to Isolatte.fork from inside an IsoLatte.fork block (reentrant)
  #
  # We are using the exit statuses of 122 and 123 as sentinels that mean
  # 'the code did not exit on its own' and 'the code raised an exception'.
  # If you have code that actually uses those exit statuses.. change the special
  # statuses I guess.
  #
  def self.fork(options = nil, &block)
    defaults = { :stderr => "/dev/null", :exit => nil }
    opts = OpenStruct.new(defaults.merge(options || {}))

    read_ex, write_ex = IO.pipe

    child_pid = Process.fork do
      read_ex.close
      begin
        if opts.stderr
          File.open(opts.stderr, "w") do |stderr_file|
            STDERR.reopen(stderr_file)
            STDERR.sync = true
            $stderr = STDERR
            block.call
          end
        else
          block.call
        end
      rescue StandardError => e
        marshal(e) # To check if it works before writing any of it to the stream
        marshal(e, write_ex)
        write_ex.flush
        write_ex.close
        exit!(EXCEPTION_RAISED)
      end

      exit!(NO_EXIT)
    end

    write_ex.close

    pid, rc =
      begin
        if opts.timeout
          Timeout.timeout(opts.timeout) { Process.wait2(child_pid) }
        else
          Process.wait2(child_pid)
        end
      rescue Timeout::Error
        kill_child(child_pid)
      end

    fail(Error, "Wrong child's exit received!") unless pid == child_pid

    if rc.exited? && rc.exitstatus == EXCEPTION_RAISED
      e = Marshal.load read_ex
      read_ex.close
      fail e
    else
      read_ex.close
    end

    success = rc.success? || rc.exitstatus == NO_EXIT
    code = rc.exitstatus == NO_EXIT ? 0 : rc.exitstatus

    if success
      opts.success.call if opts.success
    else
      opts.fault.call if opts.fault && (rc.termsig == 6 || rc.coredump?)
      opts.kill.call if opts.kill && rc.termsig == 9
    end

    # This can execute on success OR failure - it indicates that the subprocess
    # *explicitly* exited, whether with zero or nonzero.
    opts.exit.call(rc.exitstatus) if opts.exit && rc.exited? && rc.exitstatus != NO_EXIT

    # This should execute regardless of the outcome
    # (unless some other hook raises an exception first)
    opts.finish.call(success, code) if opts.finish

    rc
  end

  def self.kill_child(pid)
    Process.kill("KILL", pid)
    Process.wait2(pid)
  rescue Errno::ESRCH
    # Save us from the race condition where it exited just as we decided to kill it.
  end

  def self.marshal(e, io = nil)
    begin
      return io ? Marshal.dump(e, io) : Marshal.dump(e)
    rescue NoMethodError
    rescue TypeError
    end

    begin
      e2 = e.class.new(e.message)
      e2.set_backtrace(e.backtrace)
      return io ? Marshal.dump(e2, io) : Marshal.dump(e2)
    rescue NoMethodError
    rescue TypeError
    end

    e3 = IsoLatte::Error.new("Marshalling error with: #{e.message}")
    e3.set_backtrace(e.backtrace)
    io ? Marshal.dump(e3, io) : Marshal.dump(e3)
  end

  class Error < StandardError; end
end
