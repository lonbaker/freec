require 'rubygems'
require 'rake'
require 'echoe'

Echoe.new('freec', '0.1.0') do |p|
  p.description    = "Layer between your voice app and Freeswitch."
  p.url            = "http://github.com/jankubr/freec"
  p.author         = "Jan Kubr"
  p.email          = "hi@jankubr.com"
  p.ignore_pattern = []
  p.runtime_dependencies = ['daemons', 'eventmachine', 'extlib']
  p.development_dependencies = ['rspec']
end

require 'spec/rake/spectask'

desc "Run all specs"
Spec::Rake::SpecTask.new('spec') do |t|
  t.spec_files = FileList['spec/**/*.rb']
end