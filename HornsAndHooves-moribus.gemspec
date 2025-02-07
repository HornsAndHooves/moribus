# -*- encoding: utf-8 -*-

$:.push File.expand_path("../lib", __FILE__)
require "moribus/version"

Gem::Specification.new do |s|
  s.name        = "HornsAndHooves-moribus"
  s.version     = Moribus::VERSION
  s.authors     = ["HornsAndHooves", "Arthur Shagall", "Artem Kuzko", "Sergey Potapov"]
  s.email       = ["arthur.shagall@gmail.com", "a.kuzko@gmail.com", "blake131313@gmail.com"]
  s.homepage    = "https://github.com/HornsAndHooves/moribus"
  s.licenses    = ["MIT"]
  s.summary     = %q{Introduces Aggregated and Tracked behavior to ActiveRecord::Base models}
  s.description = %q{Introduces Aggregated and Tracked behavior to ActiveRecord::Base models, as well
    as Macros and Extensions modules for more efficient usage.}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_dependency "rails",      ">= 6"
  s.add_dependency "power_enum", ">= 2.7.0"
  s.add_dependency "yard",       ">= 0"

  s.add_development_dependency "rake"
  s.add_development_dependency "rspec"
  s.add_development_dependency "rspec-rails"
  s.add_development_dependency "sqlite3"
end
