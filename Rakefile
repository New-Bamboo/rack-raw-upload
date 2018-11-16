require 'bundler'
Bundler::GemHelper.install_tasks

require 'rake/testtask'

task :default => :test

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
end

SUPPORTED_RUBIES = %w[
  2.2.10
  2.3.8
  2.4.5
  2.5.3
  rbx-3.107
]

namespace :test do
  desc "Run all tests on multiple ruby versions (requires rvm)"
  task :portability do
    SUPPORTED_RUBIES.each do |version|
      system <<-BASH
        bash -c 'echo "--------- version #{version} ----------\n" &&
                 asdf local ruby #{version} &&
                 bundle exec rake test'
      BASH
    end
  end

  namespace :portability do
    desc "Install all Rubies and dependencies"
    task :install do
      SUPPORTED_RUBIES.each do |version|
        command_ran_ok = system <<-BASH
          bash -c 'echo "--------- version #{version} ----------\n" &&
                   asdf install ruby #{version} &&
                   asdf local ruby #{version} &&
                   gem install bundler &&
                   bundle'
        BASH
        command_ran_ok or break
      end
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
