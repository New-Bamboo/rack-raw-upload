require 'rake/testtask'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |s|
    s.name = "rack-raw-upload"
    s.summary = "rack-raw-upload (Rack Raw Upload middleware)"
    s.description = "rack-raw-upload (Rack Raw Upload middleware)"
    s.email = "max@maxschulze.com"
    s.homepage = "http://github.com/newbamboo/rack-raw-upload"
    s.authors = ["Pablo Brasero"]
    
    s.files =  FileList["{lib,test}/**/*"]
    
    s.add_dependency 'json'
    
    s.add_development_dependency "rack-test"
    s.add_development_dependency "shoulda"
  end
rescue LoadError
  puts "Jeweler not available. Install it with: gem install jeweler"
end

task :default => :test

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
end

begin
  require 'yard'
  YARD::Rake::YardocTask.new(:yardoc)
rescue LoadError
  task :yardoc do
    abort "YARD is not available. In order to run yard, you must: sudo gem install yard"
  end
end