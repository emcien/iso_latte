require File.expand_path("../lib/iso_latte/version", __FILE__)

Gem::Specification.new do |spec|
  spec.name         = "iso_latte"
  spec.version      = IsoLatte::VERSION
  spec.date         = Time.now.utc.strftime("%Y-%m-%d")
  spec.summary      = "A gem for isolating execution in a subprocess"
  spec.description  = "IsoLatte allows execution to be forked from the main process for safety"

  spec.authors      = ["Emcien Engineering", "Eric Mueller"]
  spec.email        = ["engineering@emcien.com"]
  spec.license      = "BSD-3-Clause"

  spec.files = %w(lib/iso_latte.rb lib/iso_latte/version.rb)
  spec.require_paths = ["lib"]
end
