require 'pp'
require 'sinatra/base'

class SimpleApp < Sinatra::Base

  set :root, APP_ROOT
  set :static, true

  get '/' do
    erb :index
  end

  post '/' do
    Rack::Utils.escape_html(PP.pp(params, ''))
  end

end
