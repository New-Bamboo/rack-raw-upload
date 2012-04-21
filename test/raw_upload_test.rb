require 'rubygems'
require 'rack/test'
require 'shoulda'
require 'rack-raw-upload'
require 'json'
require 'digest'
require 'rr'

class RawUploadTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include RR::Adapters::TestUnit

  def app
    opts = @middleware_opts
    Rack::Builder.new do
      use Rack::RawUpload, opts
      run Proc.new { |env| [200, {'Content-Type' => 'text/html'}, ['success']] }
    end
  end

  def setup
    @middleware_opts = {}
    @path = File.join(File.dirname(__FILE__), %w{data me-in-shanghai.jpg})
    @filename = File.basename(@path)
    @file = File.open(@path) # Maybe use mode 'rb:ASCII-8BIT'? May help with the pending test below. Not doing it for the moment, as it's not supported by Rubinius
  end

  def upload(env = {})
    env = {
      'CONTENT_TYPE' => 'application/octet-stream',
      'rack.input' => @file,
    }.merge(env)
    do_request(env)
  end

  def post(env = {})
    env = {
      'CONTENT_TYPE' => 'multipart/form-data',
      'rack.input' => StringIO.new('things=stuff'),
    }.merge(env)
    do_request(env)
  end

  def do_request(env = {})
    input = env['rack.input']
    length = input.respond_to?(:size) ? input.size : File.size(input.path)
    env = {
      'REQUEST_METHOD' => 'POST',
      'PATH_INFO' => '/some/path',
      'CONTENT_LENGTH' => length.to_s,
    }.merge(env)
    request(env['PATH_INFO'], env)
  end

  context "raw file upload" do
    should "work with PUT requests" do
      upload('REQUEST_METHOD' => 'PUT')
      assert_file_uploaded
    end

    should "work with Content-Type 'application/octet-stream'" do
      upload
      assert_file_uploaded_as 'application/octet-stream'
    end

    should "work with Content-Type 'image/jpeg'" do
      upload('CONTENT_TYPE' => 'image/jpeg')
      assert_file_uploaded_as 'image/jpeg'
    end

    should "not work with Content-Type 'application/x-www-form-urlencoded'" do
      post('CONTENT_TYPE' => 'application/x-www-form-urlencoded')
      assert_successful_non_upload
    end

    should "not work with Content-Type 'multipart/form-data'" do
      post
      assert_successful_non_upload
    end

    should "not work when there is no input" do
      upload('rack.input' => '')
      assert_successful_non_upload

      upload('rack.input' => StringIO.new(''))
      assert_successful_non_upload
    end

    # "stuff" should be something like "boundary=----WebKitFormBoundaryeKPeU4p65YgercgO",
    # but if I do that here, Rack tries to be clever and the test breaks
    should "not work with Content-Type 'multipart/form-data; stuff'" do
      post('CONTENT_TYPE' => 'multipart/form-data; stuff')
      assert_successful_non_upload
    end

    should "work when the input is a Tempfile" do
      tempfile = Tempfile.new('rack-raw-upload-test-')
      tempfile << @file.read
      tempfile.rewind
      upload('rack.input' => tempfile)
      assert_file_uploaded
    end

    # Sould be something like this, but I can't get this to fail
    # when it should. Instead, I'm testing using the example
    # undefined_conversion_error app for the time being.
    # should "work when the input is a StringIO" do
    #   rack_input = StringIO.new(@file.read)
    #   upload('rack.input' => rack_input)
    #   assert_file_uploaded
    # end

    should "be forced to perform a file upload if `X-File-Upload: true`" do
      upload('CONTENT_TYPE' => 'multipart/form-data', 'HTTP_X_FILE_UPLOAD' => 'true')
      assert_file_uploaded_as 'multipart/form-data'
    end

    should "not perform a file upload if `X-File-Upload: false`" do
      upload('CONTENT_TYPE' => 'image/jpeg', 'HTTP_X_FILE_UPLOAD' => 'false')
      assert_successful_non_upload
    end

    context "when garbage collection runs (Ruby 1.9)" do
      context "and the file is received as a Tempfile" do
        should "ensure that the uploaded file remains" do
          tempfile = Tempfile.new('rack-raw-upload-test-')
          tempfile << @file.read
          tempfile.rewind
          upload('rack.input' => tempfile)
          received = last_request.POST["file"]
          GC.start
          assert File.exists?(received[:tempfile].path)
          assert_file_uploaded
        end
      end

      context "and the file is NOT received as a TmpFile" do
        should "ensure that the uploaded file remains" do
          upload
          received = last_request.POST["file"]
          GC.start
          assert File.exists?(received[:tempfile].path)
          assert_file_uploaded
        end
      end
    end

    context "with X-File-Upload: smart" do
      should "perform a file upload if appropriate" do
        post('HTTP_X_FILE_UPLOAD' => 'smart')
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
        post('HTTP_X_FILE_UPLOAD' => 'smart')
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

    context "with JSON parameters" do
      setup do
        upload('HTTP_X_JSON_PARAMS' => JSON.generate({
          :argument => 'value1',
          'argument with spaces' => 'value 2'
        }))
      end

      should "convert these into arguments" do
        assert_equal last_request.POST['argument'], 'value1'
        assert_equal last_request.POST['argument with spaces'], 'value 2'
      end
    end

    context "with query parameters" do
      setup do
        upload('HTTP_X_PARAMS' => "arg=val1&ar+g=val2")
      end

      should "convert these into arguments" do
        assert_equal last_request.POST['arg'], 'val1'
        assert_equal last_request.POST['ar g'], 'val2'
      end
    end

    context "with query parameters, deprecated style" do
      setup do
        json_params = JSON.generate({
          :argument => 'value1',
          'argument with spaces' => 'value 2'
        })
        @mock_error_stream = obj = Object.new
        stub(obj).puts
        stub(obj).flush

        upload({
          'HTTP_X_QUERY_PARAMS' => json_params,
          'rack.errors' => @mock_error_stream
        })
      end

      should "convert these into arguments" do
        assert_equal last_request.POST['argument'], 'value1'
        assert_equal last_request.POST['argument with spaces'], 'value 2'
      end

      should "give a deprecation warning" do
        assert_received(@mock_error_stream) {|subject| subject.puts(is_a(String)) }
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
    assert received = last_request.POST["file"], "No file received"
    assert_files_equal file, received[:tempfile]
    assert last_response.ok?
  end

  def assert_file_uploaded_as(file_type)
    file = File.open(@path)
    received = last_request.POST["file"]
    assert_files_equal file, received[:tempfile]
    assert_equal file_type, received[:type]
    assert last_response.ok?
  end

  def assert_successful_non_upload
    assert ! last_request.POST.has_key?('file')
    assert last_response.ok?
  end

  def assert_files_equal(f1, f2)
    expected = Digest::MD5.hexdigest(IO.read(f1.path))
    actual   = Digest::MD5.hexdigest(IO.read(f2.path))
    assert_equal expected, actual
  end
end
