require "iso_latte"

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.order = "random"
end

TMPDIR = File.expand_path("../tmp", __FILE__)
def tmp_path(name, opts = {})
  path = File.join(TMPDIR, name)
  File.unlink(path) if opts[:clean] && File.exist?(path)
  path
end
