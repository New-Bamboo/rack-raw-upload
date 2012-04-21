require 'httparty'

class TflCountdown
  include HTTParty
  base_uri 'http://countdown.tfl.gov.uk'

  def initialize(status = {})
    @cookies = status['cookies'] if status['cookies']
  end

  def search(q)
    get_json('/search', 'searchTerm' => q)
  end

  def markers(swlat, swlng, nelat, nelng)
    path = "/markers/swLat/#{swlat}/swLng/#{swlng}/neLat/#{nelat}/neLng/#{nelng}/"
    get_json(path)
  end


  def get_json(path, query = {})
    query_params = {
      '_dc' => Time.now.to_i,
    }.merge(query)

    headers = {
      'X-Requested-With' => 'XMLHttpRequest',
      'Referer' => 'http://countdown.tfl.gov.uk/',
      'User-Agent' => 'Pablito\'s own',
    }
    headers['Cookie'] = @cookies if @cookies

    res = self.class.get(path, :query => query_params, :headers => headers, :format => :json)
    @cookies = res.headers['set-cookie']
    res.body
  end

  def to_hash
    ret = {}
    ret['cookies'] = @cookies if @cookies
    ret
  end

end