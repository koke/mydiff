Gem::Specification.new do |s|
  s.name = %q{mydiff}
  s.version = "0.0.1"

  s.specification_version = 2 if s.respond_to? :specification_version=

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Jorge Bernal"]
  s.date = %q{2008-05-13}
  s.default_executable = %q{mydiff}
  s.description = %q{== DESCRIPTION:}
  s.email = %q{jbernal@warp.es}
  s.executables = ["mydiff"]
  s.extra_rdoc_files = ["History.txt", "Manifest.txt", "README.txt"]
  s.files = ["History.txt", "Manifest.txt", "README.txt", "Rakefile", "bin/mydiff", "lib/mydiff/change.rb", "lib/mydiff/cli.rb", "lib/mydiff.rb", "test/helper.rb", "test/test_mydiff.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/koke/mydiff}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{mydiff}
  s.rubygems_version = %q{1.0.1}
  s.summary = %q{MySQL diff library}
  s.test_files = ["test/test_mydiff.rb"]

  s.add_dependency(%q<mysql>, [">= 2.7"])
  s.add_dependency(%q<highline>, [">= 1.4.0"])
  s.add_dependency(%q<hoe>, [">= 1.5.1"])
end
