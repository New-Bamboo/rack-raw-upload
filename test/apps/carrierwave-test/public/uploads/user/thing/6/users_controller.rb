class UsersController < ApplicationController

  def new
    @user = User.new
  end

  def create
    u = User.new
    u.thing = File.new(__FILE__)
    u.save!
    render :text => %{<a href="#{u.thing.url}">#{u.thing.url}</a>}
  end

end