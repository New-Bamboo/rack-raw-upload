$: << '.' << 'lib'
require 'app'
require 'rack/raw_upload'

use Rack::RawUpload
run SimpleApp
