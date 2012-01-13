class Rack::RawUpload

  module Qualifiers
    def html5_upload?( env )
      env['HTTP_X_FILE_UPLOAD'] == 'true'                                         || 
      ! @explicit && env['HTTP_X_FILE_UPLOAD'] != 'false' && raw_file_upload?( env ) || 
      env.has_key?('HTTP_X_FILE_UPLOAD') && env['HTTP_X_FILE_UPLOAD'] != 'false' && raw_file_upload?( env )
    end

    def raw_file_upload?( env )
      upload_path?( env['PATH_INFO'] ) &&
        %{POST PUT}.include?( env['REQUEST_METHOD'] ) &&
        content_type_of_raw_file?( env['CONTENT_TYPE'] ) &&
        env['CONTENT_LENGTH'].to_i > 0
    end

    def literal_path_match?( request_path, candidate )
      candidate == request_path
    end

    def wildcard_path_match?( request_path, candidate )
      return false unless candidate.include?( '*' )
      regexp = '^' + candidate.gsub( '.', '\.' ).gsub( '*', '[^/]*' ) + '$'
      !! ( Regexp.new( regexp ) =~ request_path )
    end

    def content_type_of_raw_file?( content_type )
      case content_type
      when %r{^application/x-www-form-urlencoded}, %r{^multipart/form-data}
        false
      else
        true
      end
    end
  end
end