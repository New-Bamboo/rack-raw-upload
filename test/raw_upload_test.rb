require 'rubygems'
require 'rack/test'
require 'shoulda'
require 'rack/raw_upload'

class RawUploadTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Rack::Builder.new do
      use Rack::RawUpload, :paths => '/some/path'
      run Proc.new { |env| [200, {'Content-Type' => 'text/html'}, ['success']] }
    end
  end

  context "raw file upload" do
    setup do
      @path = __FILE__
      @filename = File.basename(@path)
      @file = File.open(@path)
      query_params = {
        :argument => 'value1',
        'argument with spaces' => 'value 2'
      }
      env = {
        'REQUEST_METHOD' => 'POST',
        'CONTENT_TYPE' => 'application/octet-stream',
        'HTTP_X_QUERY_PARAMS' => JSON.generate(query_params),
        'PATH_INFO' => '/some/path',
        'HTTP_X_FILE_NAME' => @filename,
        'rack.input' => @file,
      }
      request(env['PATH_INFO'], env)
    end

    should "be transformed into a normal form upload" do
      file = File.open(@path)
      received = last_request.POST["file"]
      received[:tempfile].open
      assert_equal received[:tempfile].gets, file.gets
      assert_equal received[:filename], @filename
      assert_equal received[:type], "application/octet-stream"
    end

    should "convert any additional parameters from headers to arguments" do
      assert_equal last_request.POST['argument'], 'value1'
      assert_equal last_request.POST['argument with spaces'], 'value 2'
    end
  
    should "succeed" do
      assert last_response.ok?
    end
  end
  
  context "path matcher" do
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
    end
    
    should "accept several entries" do
      rru = Rack::RawUpload.new nil, :paths => ['/resources.*', '/uploads']
      assert rru.upload_path?('/uploads')
      assert rru.upload_path?('/resources.*')
      assert ! rru.upload_path?('/upload')
    end
  end
end