lib     = File.expand_path("../lib/rack/raw_upload.rb", __FILE__)
version = File.read(lib)[/^\s*VERSION\s*=\s*(['"])(\d\.\d\.\d+)\1/, 2] #'# gedit messing with highlighting...

Gem::Specification.new do |spec|
  spec.name = 'rack-raw-upload'
  spec.authors = "Pablo Brasero"
  spec.email = "pablobm@gmail.com"
  spec.homepage = 'https://github.com/newbamboo/rack-raw-upload'
  spec.summary = %{Rack Raw Upload middleware}
  spec.description = %{Middleware that converts files uploaded with mimetype application/octet-stream into normal form input, so Rack applications can read these as normal, rather than as raw input.}
  spec.extra_rdoc_files = %w{LICENSE README.md}
  spec.rdoc_options << "--charset=UTF-8" <<
                       "--main" << "README.rdoc"
  spec.version = version
  spec.files = Dir["{lib,test}/**/*.rb"] + spec.extra_rdoc_files + %w{Gemfile Gemfile.lock}
  spec.test_files = spec.files.grep(/^test\/.*test_.*\.rb$/)

  spec.add_runtime_dependency 'json'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rack-test'
  spec.add_development_dependency 'shoulda'
end

