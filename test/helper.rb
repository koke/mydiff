require 'rubygems'
require 'test/unit'
require File.join(File.dirname(__FILE__), *%w[.. lib mydiff])

def absolute_project_path
  File.expand_path(File.join(File.dirname(__FILE__), '..'))
end
