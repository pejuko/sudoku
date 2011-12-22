require 'rubygems'
require 'rake'

task :default => [:spec]

$:.unshift(File.expand_path File.dirname(__FILE__))

Dir["tasks/*.rake"].each do |rake_task|
  load rake_task
end
