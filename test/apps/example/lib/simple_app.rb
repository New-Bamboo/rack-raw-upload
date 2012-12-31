require 'pp'
require 'sinatra/base'
require 'multi_json'

class SimpleApp < Sinatra::Base

  set :root, APP_ROOT
  set :static, true
  set :public_folder, Proc.new{ File.join(root, 'public') }
  set :upload_dir, Proc.new{ File.join(public_folder, 'uploads') }

  configure do
    FileUtils.mkdir_p(settings.upload_dir)
  end

  get '/' do
    erb :index
  end

  post '/' do
    content_type :json
    dump = Rack::Utils.escape_html(PP.pp(params, ''))
    download_url = file_url(store_file(params[:file]))
    MultiJson.dump({
      :dump => dump,
      :download_url => download_url,
    })
  end


  private

  def store_file(file_param)
    dirpath = Dir.mktmpdir(nil, settings.upload_dir)
    filepath = File.join(dirpath, file_param[:filename])
    FileUtils.mv(file_param[:tempfile], filepath)
    filepath
  end

  def file_url(path)
    path.gsub(Regexp.new('^' + settings.public_folder), '').tap{|x| pp x}
  end

end
