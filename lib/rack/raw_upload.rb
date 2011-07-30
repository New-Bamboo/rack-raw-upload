require 'tmpdir' # Needed in 1.8.7 to access Dir::tmpdir

module Rack
  class RawUpload

    VERSION = '1.0.6'

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
      tempfile = Tempfile.new('raw-upload.', @tmpdir)
      if (RUBY_VERSION.split('.').map{|e| e.to_i} <=> [1, 9]) > 0
        # 1.8.7: if the 'original' tempfile has no open file-handler,
        # the garbage collector will unlink this file.
        # in this case, only the path to the 'original' tempfile is used
        # and the physical file will be deleted, if the gc runs.
        tempfile2 = relink_file(tempfile)
        tempfile.close
        tempfile = tempfile2
      end
      tempfile << env['rack.input'].read
      tempfile.flush
      tempfile.rewind
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
      if query_params = env['HTTP_X_QUERY_PARAMS']
        require 'json'
        params = JSON.parse(query_params)
        env['rack.request.form_hash'].merge!(params)
        env['rack.request.query_hash'].merge!(params)
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
        content_type_of_raw_file?(env['CONTENT_TYPE'])
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

    def relink_file(file)
      new_name = file.path + random_string
      ::File.link(file.path, new_name)
      ret = ::File.open(new_name, "r+")
      ret.binmode
      ret
    rescue SystemCallError
      # The randomly chosen file name was taken. Try again.
      retry
    end

    def random_string
      (0...8).map{65.+(rand(25)).chr}.join
    end
  end
end
