require 'tmpdir' # Needed in 1.8.7 to access Dir::tmpdir

module Rack
  class RawUpload

    VERSION = '1.1.0'

    def initialize(app, opts = {})
      @app = app
      @paths = opts[:paths]
      @explicit = opts[:explicit]
      @tmpdir = opts[:tmpdir] || Dir::tmpdir
      @paths = [@paths] if @paths.kind_of?(String)
    end

    def call(env)
      kick_in?(env) ? convert_and_pass_on(env) : @app.call(env)
    end

    def upload_path?(request_path)
      return true if @paths.nil?

      @paths.any? do |candidate|
        literal_path_match?(request_path, candidate) || wildcard_path_match?(request_path, candidate)
      end
    end


    private

    def convert_and_pass_on(env)
      if env['rack.input'].kind_of?(Tempfile)
        env['rack.input'].extend(EqlFix)
        tempfile = env['rack.input']
      else
        tempfile = Tempfile.new('raw-upload.', @tmpdir)

        # Can't get to produce a test case for this :-(
        env['rack.input'].each do |chunk|
          if chunk.respond_to?(:force_encoding)
            tempfile << chunk.force_encoding('UTF-8')
          else
            tempfile << chunk
          end
        end

        tempfile.flush
        tempfile.rewind
      end
      fake_file = {
        :filename => env['HTTP_X_FILE_NAME'],
        :type => env['CONTENT_TYPE'],
        :tempfile => tempfile,
      }
      env['rack.request.form_input'] = env['rack.input']
      env['rack.request.form_hash'] ||= {}
      env['rack.request.query_hash'] ||= {}
      env['rack.request.form_hash']['file'] = fake_file
      env['rack.request.query_hash']['file'] = fake_file
      if env['HTTP_X_QUERY_PARAMS']
        env['rack.errors'].puts("Warning! The header X-Query-Params is deprecated. Please use X-JSON-Params instead.")
        inject_json_params!(env, env['HTTP_X_QUERY_PARAMS'])
      end
      if env['HTTP_X_JSON_PARAMS']
        inject_json_params!(env, env['HTTP_X_JSON_PARAMS'])
      end
      if env['HTTP_X_PARAMS']
        inject_query_params!(env, env['HTTP_X_PARAMS'])
      end
      @app.call(env)
    end

    def kick_in?(env)
      env['HTTP_X_FILE_UPLOAD'] == 'true' ||
        ! @explicit && env['HTTP_X_FILE_UPLOAD'] != 'false' && raw_file_upload?(env) ||
        env.has_key?('HTTP_X_FILE_UPLOAD') && env['HTTP_X_FILE_UPLOAD'] != 'false' && raw_file_upload?(env)
    end

    def raw_file_upload?(env)
      upload_path?(env['PATH_INFO']) &&
        %{POST PUT}.include?(env['REQUEST_METHOD']) &&
        content_type_of_raw_file?(env['CONTENT_TYPE']) &&
        env['CONTENT_LENGTH'].to_i > 0
    end

    def literal_path_match?(request_path, candidate)
      candidate == request_path
    end

    def wildcard_path_match?(request_path, candidate)
      return false unless candidate.include?('*')
      regexp = '^' + candidate.gsub('.', '\.').gsub('*', '[^/]*') + '$'
      !! (Regexp.new(regexp) =~ request_path)
    end

    def content_type_of_raw_file?(content_type)
      case content_type
      when %r{^application/x-www-form-urlencoded}, %r{^multipart/form-data}
        false
      else
        true
      end
    end

    def random_string
      (0...8).map{65.+(rand(25)).chr}.join
    end

    def inject_json_params!(env, params)
      require 'json'
      hsh = JSON.parse(params)
      env['rack.request.form_hash'].merge!(hsh)
      env['rack.request.query_hash'].merge!(hsh)
    end

    def inject_query_params!(env, params)
      hsh = Rack::Utils.parse_query(params)
      env['rack.request.form_hash'].merge!(hsh)
      env['rack.request.query_hash'].merge!(hsh)
    end
  end


  module EqlFix
    def eql_with_fix?(o)
      self.object_id.eql?(o.object_id) || self.eql_without_fix?(o)
    end

    alias_method :eql_without_fix?, :eql?
    alias_method :eql?, :eql_with_fix?
  end

end
