#!/usr/bin/env rake
require 'rake/dsl_definition' 
begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end
require 'rspec/core/rake_task'

Bundler::GemHelper.install_tasks

# RSpec tasks.
RSpec::Core::RakeTask.new :spec
task :default => :spec
