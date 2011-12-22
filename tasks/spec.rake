$spec_files = Dir["spec/*.rb"]

desc "Test sudoku"
task :spec do |t|
  system "rspec -c #{$spec_files.join(' ')}"
end
