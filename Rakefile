require 'rubygems'
require "rake/gempackagetask"
require "rake/rdoctask"
require "rake/testtask"
require 'hoe'
require './lib/mydiff.rb'

Hoe.new('mydiff', MyDiff::VERSION) do |p|
  p.author = 'Jorge Bernal'
  p.email = 'jbernal@warp.es'
  p.summary = 'MySQL diff library'
  p.description = p.paragraphs_of('README.txt', 2..2).join("\n\n")
  p.url = p.paragraphs_of('README.txt', 1).first
  p.changes = p.paragraphs_of('History.txt', 0..1).join("\n\n")
  p.extra_deps << ['mysql','>= 2.7']
  p.extra_deps << ['highline', '>= 1.4.0']
  p.remote_rdoc_dir = ''
end

desc "Open an irb session preloaded with this library"
task :console do
  sh "irb -rubygems -r ./lib/mydiff.rb"
end

desc "Run coverage tests"
task :coverage do
  system("rm -fr coverage")
  system("rcov test/test_*.rb")
  system("open coverage/index.html")
end
