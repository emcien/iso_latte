require "spec_helper"
require "fileutils"
require "segfault"
require "english"

describe "IsoLatte.fork" do
  before(:each) do
    @exit_status = nil
    @killed = @faulted = @exited = @finished = @success = false
  end

  def kill_self!; `kill -9 #{$PROCESS_ID}`; end

  def segfault!; Segfault.dereference_null; end

  let(:on_kill) { ->() { @killed = true } }
  let(:on_fault) { ->() { @faulted = true } }
  let(:on_exit) { ->(rc) { @exited, @exit_status = [true, rc] } }
  let(:on_finish) { ->(_s, c) { @finished, @exit_status = [true, c] } }
  let(:on_success) { ->() { @success = true } }

  let(:opts) do
    { success: on_success,
      kill: on_kill,
      exit: on_exit,
      finish: on_finish,
      fault: on_fault }
  end

  it "should run the block in a subprocess" do
    @ran_here = nil
    IsoLatte.fork do
      @ran_here = true
      FileUtils.touch tmp_path("ran_at_all", clean: true)
    end

    expect(@ran_here).to be_nil
    expect(File.exist?(tmp_path "ran_at_all")).to be_true
  end

  it "should write stderr to the specified location" do
    IsoLatte.fork(stderr: tmp_path("fork.err", clean: true)) do
      warn "line 1"
      warn "line 2"
    end

    expect(File.exist? tmp_path("fork.err")).to eq(true)
    expect(File.read(tmp_path "fork.err")).to eq("line 1\nline 2\n")
  end

  it "should not redirect stderr if opts.stderr is nil" do
    $stderr = s = StringIO.open("", "w")
    IsoLatte.fork(stderr: nil) do
      warn "again"
      File.write(tmp_path("fork2.stderr", clean: true), s.string)
    end
    $stderr = STDERR

    expect(File.read(tmp_path "fork2.stderr").strip).to eq("again")
  end

  it "should handle a clean finish correctly" do
    IsoLatte.fork(opts) { warn "do nothing" }
    expect(@killed).to eq(false)
    expect(@faulted).to eq(false)
    expect(@exited).to eq(false)
    expect(@finished).to eq(true)
    expect(@success).to eq(true)
  end

  it "should handle an explicit successful exit correctly" do
    IsoLatte.fork(opts) { exit! 0 }
    expect(@killed).to eq(false)
    expect(@faulted).to eq(false)
    expect(@exited).to eq(true)
    expect(@finished).to eq(true)
    expect(@success).to eq(true)
    expect(@exit_status).to eq(0)
  end

  it "should handle an explicit nonzero exit correctly" do
    IsoLatte.fork(opts) { exit! 12 }
    expect(@killed).to eq(false)
    expect(@faulted).to eq(false)
    expect(@exited).to eq(true)
    expect(@finished).to eq(true)
    expect(@success).to eq(false)
    expect(@exit_status).to eq(12)
  end

  it "should handle a SIGKILL correctly" do
    IsoLatte.fork(opts) { kill_self! }
    expect(@killed).to eq(true)
    expect(@faulted).to eq(false)
    expect(@exited).to eq(false)
    expect(@finished).to eq(true)
    expect(@success).to eq(false)
  end

  it "should handle a segfault correctly" do
    IsoLatte.fork(opts) { segfault! }
    expect(@killed).to eq(false)
    expect(@faulted).to eq(true)
    expect(@exited).to eq(false)
    expect(@finished).to eq(true)
    expect(@success).to eq(false)
  end

  it "should allow recursive isolation" do
    IsoLatte.fork(opts) do
      IsoLatte.fork(opts) do
        IsoLatte.fork(opts) do
          segfault!
        end
        kill_self!
      end

      exit(15)
    end

    expect(@killed).to eq(false)
    expect(@faulted).to eq(false)
    expect(@exited).to eq(true)
    expect(@exit_status).to eq(15)
  end

  it "should raise exceptions out of the isolated process" do
    expect do
      IsoLatte.fork(opts) do
        fail ArgumentError, "Foo bar bar bar"
      end
    end.to raise_exception(ArgumentError, "Foo bar bar bar")
  end
end
