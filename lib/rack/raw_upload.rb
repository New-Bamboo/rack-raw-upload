require 'tmpdir' # Needed in 1.8.7 to access Dir::tmpdir
require 'addressable/uri'

module Rack
  class RawUpload
    include Qualifiers
    include Helpers

    VERSION = '1.0.12'

    def initialize( app, opts = {} )
      @app      = app
      @paths    = opts[:paths]
      @explicit = opts[:explicit]
      @tmpdir   = opts[:tmpdir] || Dir::tmpdir
      @paths    = [@paths] if @paths.kind_of?( String )
    end

    def call( env )
      html5_upload?( env ) ? convert_and_pass_on( env ) : @app.call( env )
    end

    def upload_path?( request_path )
      return true if @paths.nil?

      @paths.any? do |candidate|
        literal_path_match?( request_path, candidate ) || wildcard_path_match?( request_path, candidate )
      end
    end

    private

    def convert_and_pass_on( env )
      fake_file = create_fake_file( env )

      env['rack.request.form_input']   = env['rack.input']
      env['rack.request.form_hash']  ||= {}
      env['rack.request.query_hash'] ||= {}

      if file_params = env['HTTP_X_FILE_KEY']
        # Place file in the hash provided
        params = put_file_in_hash( file_params, fake_file )
        # merge in params
        env['rack.request.form_hash'].merge!(params)
        env['rack.request.query_hash'].merge!(params)
      else
        env['rack.request.form_hash']['file']  = fake_file
        env['rack.request.query_hash']['file'] = fake_file
      end
      
      if query_params = env['HTTP_X_QUERY_PARAMS']
        params = Addressable::URI.new(query: query_params).query_values
        env['rack.request.form_hash'].merge!(params)
        env['rack.request.query_hash'].merge!(params)
      end
      @app.call( env )
    end

    def create_fake_file( env )
      if env['rack.input'].kind_of?( Tempfile )
        env['rack.input'].extend( EqlFix )
        tempfile = env['rack.input']
      else
        tempfile = Tempfile.new( 'raw-upload.', @tmpdir )
        # Can't get to produce a test case for this :-(
        env['rack.input'].each do |chunk|
          if chunk.respond_to?( :force_encoding )
            tempfile << chunk.force_encoding( 'UTF-8' )
          else
            tempfile << chunk
          end
        end

        tempfile.flush
        tempfile.rewind
      end

      fake_file = { :filename => env['HTTP_X_FILE_NAME'],
                    :type     => env['CONTENT_TYPE'],
                    :tempfile => tempfile }
    end
  end
end
