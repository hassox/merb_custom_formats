class MainController < Merb::Controller
  provides :iphone, :android, :yaml, :xml
  def index
    "#{content_type.inspect}"
  end  
end