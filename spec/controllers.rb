class MainController < Merb::Controller
  provides :iphone, :android, :yaml
  def index
    "#{content_type.inspect}"
  end  
end