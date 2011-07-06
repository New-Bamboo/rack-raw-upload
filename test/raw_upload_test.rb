require 'rubygems'
require 'rack/test'
require 'shoulda'
require 'rack-raw-upload'
require 'json'

class RawUploadTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    opts = @middleware_opts
    Rack::Builder.new do
      use Rack::RawUpload, opts
      run Proc.new { |env| [200, {'Content-Type' => 'text/html'}, ['success']] }
    end
  end

  def setup
    @middleware_opts = {}
    @path = __FILE__
    @filename = File.basename(@path)
    @file = File.open(@path)
  end

  def upload(env = {})
    env = {
      'REQUEST_METHOD' => 'POST',
      'CONTENT_TYPE' => 'application/octet-stream',
      'PATH_INFO' => '/some/path',
      'rack.input' => @file,
    }.merge(env)
    request(env['PATH_INFO'], env)
  end

  context "raw file upload" do
    should "work with PUT requests" do
      upload('REQUEST_METHOD' => 'PUT')
      assert_file_uploaded
    end

    should "work with Content-Type 'application/octet-stream'" do
      upload('CONTENT_TYPE' => 'application/octet-stream')
      assert_file_uploaded_as 'application/octet-stream'
    end

    should "work with Content-Type 'image/jpeg'" do
      upload('CONTENT_TYPE' => 'image/jpeg')
      assert_file_uploaded_as 'image/jpeg'
    end

    should "not work with Content-Type 'application/x-www-form-urlencoded'" do
      upload('CONTENT_TYPE' => 'application/x-www-form-urlencoded')
      assert_successful_non_upload
    end

    should "not work with Content-Type 'multipart/form-data'" do
      upload('CONTENT_TYPE' => 'multipart/form-data')
      assert_successful_non_upload
    end

    # "stuff" should be something like "boundary=----WebKitFormBoundaryeKPeU4p65YgercgO",
    # but if I do that here, Rack tries to be clever and the test breaks
    should "not work with Content-Type 'multipart/form-data; stuff'" do
      upload('CONTENT_TYPE' => 'multipart/form-data; stuff')
      assert_successful_non_upload
    end
    
    should "be forced to perform a file upload if `X-File-Upload: true`" do
      upload('CONTENT_TYPE' => 'multipart/form-data', 'HTTP_X_FILE_UPLOAD' => 'true')
      assert_file_uploaded_as 'multipart/form-data'
    end

    should "not perform a file upload if `X-File-Upload: false`" do
      upload('CONTENT_TYPE' => 'image/jpeg', 'HTTP_X_FILE_UPLOAD' => 'false')
      assert_successful_non_upload
    end

    should "be compatible to rails 1.8.7 and tempfile must exist after garbage collection" do
      upload('CONTENT_TYPE' => 'application/octet-stream')
      received = last_request.POST["file"]
      GC.start
      assert File.exists?(received[:tempfile].path)
    end

    context "with X-File-Upload: smart" do
      should "perform a file upload if appropriate" do
        upload('CONTENT_TYPE' => 'multipart/form-data', 'HTTP_X_FILE_UPLOAD' => 'smart')
        assert_successful_non_upload
      end

      should "not perform a file upload if not appropriate" do
        upload('CONTENT_TYPE' => 'image/jpeg', 'HTTP_X_FILE_UPLOAD' => 'smart')
        assert_file_uploaded_as 'image/jpeg'
      end
    end

    context "with :explicit => true" do
      setup do
        @middleware_opts = { :explicit => true }
      end

      should "not be triggered by an appropriate Content-Type" do
        upload('CONTENT_TYPE' => 'image/jpeg')
        assert_successful_non_upload
      end

      should "be triggered by `X-File-Upload: true`" do
        upload('CONTENT_TYPE' => 'image/jpeg', 'HTTP_X_FILE_UPLOAD' => 'true')
        assert_file_uploaded_as 'image/jpeg'
      end

      should "kick in when `X-File-Upload: smart` and the request is an upload" do
        upload('CONTENT_TYPE' => 'image/jpeg', 'HTTP_X_FILE_UPLOAD' => 'smart')
        assert_file_uploaded_as 'image/jpeg'
      end

      should "stay put when `X-File-Upload: smart` and the request is not an upload" do
        upload('CONTENT_TYPE' => 'multipart/form-data', 'HTTP_X_FILE_UPLOAD' => 'smart')
        assert_successful_non_upload
      end
    end

    context "with a given :tmpdir" do
      setup do
        @tmp_path = File.join(Dir::tmpdir, 'rack-raw-upload/some-dir')
        FileUtils.mkdir_p(@tmp_path)
        @middleware_opts = { :tmpdir => @tmp_path }
      end

      should "use it as temporary file store" do
        upload
        assert Dir.entries(@tmp_path).any?{|node| node =~ /raw-upload/ }
      end
    end

    context "with query parameters" do
      setup do
        upload('HTTP_X_QUERY_PARAMS' => JSON.generate({
          :argument => 'value1',
          'argument with spaces' => 'value 2'
        }))
      end

      should "convert these into arguments" do
        assert_equal last_request.POST['argument'], 'value1'
        assert_equal last_request.POST['argument with spaces'], 'value 2'
      end
    end

    context "with filename" do
      setup do
        upload('HTTP_X_FILE_NAME' => @filename)
      end

      should "be transformed into a normal form upload" do
        assert_equal @filename, last_request.POST["file"][:filename]
      end
    end
  end
  
  context "path matcher" do
    should "accept any path by default" do
      rru = Rack::RawUpload.new(nil)
      assert rru.upload_path?('/')
      assert rru.upload_path?('/resources.json')
      assert rru.upload_path?('/resources/stuff.json')
    end

    should "accept literal paths" do
      rru = Rack::RawUpload.new nil, :paths => '/resources.json'
      assert rru.upload_path?('/resources.json')
      assert ! rru.upload_path?('/resources.html')
    end

    should "accept paths with wildcards" do
      rru = Rack::RawUpload.new nil, :paths => '/resources.*'
      assert rru.upload_path?('/resources.json')
      assert rru.upload_path?('/resources.*')
      assert ! rru.upload_path?('/resource.json')
      assert ! rru.upload_path?('/resourcess.json')
      assert ! rru.upload_path?('/resources.json/blah')
    end
    
    should "accept several entries" do
      rru = Rack::RawUpload.new nil, :paths => ['/resources.*', '/uploads']
      assert rru.upload_path?('/uploads')
      assert rru.upload_path?('/resources.*')
      assert ! rru.upload_path?('/upload')
    end
  end

  def assert_file_uploaded
    file = File.open(@path)
    received = last_request.POST["file"]
    assert_equal file.gets, received[:tempfile].gets
    assert last_response.ok?
  end
  
  def assert_file_uploaded_as(file_type)
    file = File.open(@path)
    received = last_request.POST["file"]
    assert_equal file.gets, received[:tempfile].gets
    assert_equal file_type, received[:type]
    assert last_response.ok?
  end

  def assert_successful_non_upload
    assert ! last_request.POST.has_key?('file')
    assert last_response.ok?
  end
end
