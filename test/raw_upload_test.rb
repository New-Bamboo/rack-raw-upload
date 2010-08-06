require 'rubygems'
require 'rack/test'
require 'shoulda'
require 'rack/raw_upload'
require 'json'

class RawUploadTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Rack::Builder.new do
      use Rack::RawUpload
      run Proc.new { |env| [200, {'Content-Type' => 'text/html'}, ['success']] }
    end
  end

  def setup
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
    context "" do
      setup do
        upload
      end

      should "be transformed into a normal form upload" do
        file = File.open(@path)
        received = last_request.POST["file"]
        assert_equal received[:tempfile].gets, file.gets
        assert_equal received[:type], "application/octet-stream"
      end

      should "succeed" do
        assert last_response.ok?
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
end