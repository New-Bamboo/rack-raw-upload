require 'pp'

class TestController < ApplicationController

  def index
    return unless request.post?

    output = ''
    PP.pp(params, output)
    render :text => output
  end

end
