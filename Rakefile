require 'bundler'
Bundler::GemHelper.install_tasks

require 'rake/testtask'

task :default => :test

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
end

namespace :test do
  desc "Run all tests on multiple ruby versions (requires rvm)"
  task :portability do
    %w[1.8.7 1.9.2 ree rbx jruby].each do |version|
      system <<-BASH
        bash -c 'source ~/.rvm/scripts/rvm;
                 echo "--------- version #{version} ----------\n";
                 rvm #{version};
                 bundle install 1> /dev/null;
                 rake test'
      BASH
    end
  end
end


begin
  require 'yard'
  YARD::Rake::YardocTask.new(:yardoc)
rescue LoadError
  task :yardoc do
    abort "YARD is not available. In order to run yard, you must: sudo gem install yard"
  end
end
