require 'json'

module Rack
  class RawUpload

    def initialize(app, opts = {})
      @app = app
      @opts = opts
    end

    def call(env)
      raw_file_post?(env) ? convert_and_pass_on(env) : @app.call(env)
    end

    def upload_path?(path)
      literal_path_match?(path) || wildcard_path_match?(path)
    end


    private

    def convert_and_pass_on(env)
      tempfile = Tempfile.new('raw-upload.')
      tempfile << env['rack.input'].read
      tempfile.close
      fake_file = {
        :filename => env['HTTP_X_FILE_NAME'],
        :type => 'application/octet-stream',
        :tempfile => tempfile,
      }
      env['rack.request.form_input'] = env['rack.input']
      env['rack.request.form_hash'] ||= {}
      env['rack.request.query_hash'] ||= {}
      env['rack.request.form_hash']['file'] = fake_file
      env['rack.request.query_hash']['file'] = fake_file
      if query_params = env['HTTP_X_QUERY_PARAMS']
        params = JSON.parse(query_params)
        env['rack.request.form_hash'].merge!(params)
        env['rack.request.query_hash'].merge!(params)
      end
      @app.call(env)
    end

    def raw_file_post?(env)
      upload_path?(env['PATH_INFO']) &&
        env['REQUEST_METHOD'] == 'POST' &&
        env['CONTENT_TYPE'] == 'application/octet-stream'
    end

    def literal_path_match?(path)
      path == @opts[:path]
    end

    def wildcard_path_match?(path)
      upload_path = @opts[:path]
      return false unless upload_path.include?('*')
      regexp = '^' + upload_path.gsub(/\*/, '.*') + '$'
      !! (Regexp.new(regexp) =~ path)
    end
  end
end