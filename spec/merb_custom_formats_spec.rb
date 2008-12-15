require File.dirname(__FILE__) + '/spec_helper'
require File.dirname(__FILE__) + '/controllers'

describe "merb_custom_formats" do
  
  before(:each) do
    Merb::CustomFormats.clear_custom_formats!
  end
  
  it "should add a mime type to merb" do
    Merb.available_mime_types.keys.should_not include(:format)
    
    Merb::CustomFormats.add(:format) do
      mime_types "application/x-yaml", "text/yaml"
    end
    
    Merb.available_mime_types.keys.should include(:format)
    format = Merb.available_mime_types[:format]
    format[:default_quality].should == 1
    format[:accepts].should == ["application/x-yaml", "text/yaml"]
    format[:transform_method].should == :to_format
  end
  
  it "should remove custom formats from merb" do
    Merb::CustomFormats.add(:format) do
      mime_types "application/x-yaml"
    end
    Merb.available_mime_types.keys.should include(:format)
    Merb::CustomFormats.custom_formats.should include(:format)
    Merb::CustomFormats.clear_custom_formats!
    Merb.available_mime_types.keys.should_not include(:format)
    Merb::CustomFormats.custom_formats.should_not include(:format)
  end
  
  it "should raise an error if the mime_types are not set" do
    lambda do
      Merb::CustomFormats.add(:format){}
    end.should raise_error
  end
  
  it "should allow you to customise the transform_method" do
    Merb::CustomFormats.add(:foo) do
      mime_types "foo"
      transform_method :bar
    end
    Merb.available_mime_types[:foo][:transform_method].should == :bar
  end
  
  it "should allow you to customise the headers" do
    Merb::CustomFormats.add(:bar) do
      mime_types "bar"
      headers :foo => "bar"
    end
    Merb.available_mime_types[:bar][:response_headers].should == {:foo => "bar"}
  end
  
  it "should allow you to customise the default quality" do
    Merb::CustomFormats.add(:baz) do
      mime_types "baz"
      quality 0.654
    end
    Merb.available_mime_types[:baz][:default_quality].should == 0.654
  end
  
  it "should allow you to set a custom matcher for the request" do
    Merb::CustomFormats.add(:bob) do
      mime_types "bob"
      selector do |request, params|
        "boo"
      end
    end
    Merb::CustomFormats.router_procs[:bob].should be_a_kind_of(Proc)
  end
  
  it "should remove the procs from a custom matcher" do
    Merb::CustomFormats.add(:ted) do
      mime_types "ted"
      selector do |request, params|
        "ted"
      end
    end
    Merb::CustomFormats.router_procs[:ted].should be_a_kind_of(Proc)
    Merb::CustomFormats.clear_custom_formats!
    Merb::CustomFormats.router_procs.should be_empty
  end
  
  it "should not setup a custom proc for types without custom matchers" do
    Merb::CustomFormats.add(:laney) do
      mime_types "laney"
    end
    Merb::CustomFormats.router_procs.keys.should_not include(:laney)
  end
  
  it "should track the custom formats that have been setup by Merb::CustomFormats" do
    Merb::CustomFormats.add(:foo){ mime_types "foo" }
    Merb::CustomFormats.add(:bar){ mime_types "bar" }
    Merb::CustomFormats.custom_formats.should == [:foo,:bar]
  end
  
  describe "router helper" do
    before(:all) do
      Merb::Config[:exception_details] = true
      Merb::Router.prepare do
        with(:controller => "main_controller") do
          custom_formats do
            match("/foo(.:format)").register
          end
        
          custom_formats(:iphone) do
            match("/foo_for_iphone").register
          end
        
          custom_formats(:force => true) do
            match("/force_all(.:format)").register
          end
          
          custom_formats(:iphone, :force => true) do
            match("/force_iphone(.:format)").register
          end
          
          match("/foo_with_no_custom_formats").register
        end
      end
    
      @iphone_ua  = "Mozilla/5.0 (iPhone; U; CPU iPhone OS 2_1 like Mac OS X; en-us) AppleWebKit/525.18.1 (KHTML, like Gecko) Version/3.1.1 Mobile/5F136 Safari/525.20"
      @android_ua = "Mozilla/5.0 (Linux; U; Android 0.5; en-us) AppleWebKit/522+ (KHTML, like Gecko) Safari/419.3"
    end
    

    before(:each) do
      Viking.captures.clear
      Merb::CustomFormats.add(:iphone) do
        mime_type "iphone"
        selector do |request, params|
          Viking.capture(:iphone)
          request.env["User-Agent"] && request.env["User-Agent"] =~ /iPhone/i
        end
      end
      
      Merb::CustomFormats.add(:android) do
        mime_type "android"
        selector do |request, params|
          Viking.capture(:android)
          request.env["User-Agent"] && request.env["User-Agent"] =~ /Android/i
        end       
      end
      
      Merb::CustomFormats.add(:foo) do
        mime_type "foo"
      end
    end
    
    it "should check all formats registered with selectors" do
      response = request("/foo")
      response.should be_successful
      Viking.captures.should include(:iphone)
      Viking.captures.should include(:android)
      Viking.captures.should_not include(:foo)
    end
    
    it "should set the format to :html if there is nothing matching" do
      response = request("/foo")
      response.body.should == ":html"
    end
    
    it "should set the format if successful" do
      response = request("/foo", "User-Agent" => @iphone_ua)
      response.body.should == ":iphone"
    end
    
    it "should set the format to android if successful" do
      response = request("/foo", "User-Agent" => @android_ua)
      response.body.should == ":android"
    end
    
    it "should not run the android selector when the route helper only has :iphone specified" do
      response = request("/foo_for_iphone")
      Viking.captures.should include(:iphone)
      Viking.captures.should_not include(:android)
    end
    
    it "should set the format to iphone" do
      response = request("/foo_for_iphone", "User-Agent" => @iphone_ua)
      response.body.should == ":iphone"
    end
    
    it "should set the format to :html when supplied for an android ua, but in a scoped block" do
      response = request("/foo_for_iphone", "User-Agent" => @android_ua)
      response.body.should == ":html"
    end
    
    it "should not run any selectors when the format is already set" do
      response = request("/foo.yaml", "User-Agent" => @iphone_ua)      
      response.body.should == ":yaml"
      Viking.captures.should_not include(:iphone)
      Viking.captures.should_not include(:android)
    end
    
    it "should not run any selectors when the route is not covered by the custom_formats block" do
      response = request("/foo_with_no_custom_formats", "User-Agent" => @iphone_ua)
      response.body.should == ":html"
      Viking.captures.should_not include(:iphone)
      Viking.captures.should_not include(:android)
    end
    
    it "should force check the custom formats when a format is set via .format" do
      response = request("/force_all.xml")
      response.body.should == ":xml"
      Viking.captures.should include(:iphone)
      Viking.captures.should include(:android)
    end
    
    it "should force check the custom formats for a particular format" do
      response = request("/force_iphone.xml")
      response.body.should == ":xml"
      Viking.captures.should include(:iphone)
      Viking.captures.should_not include(:android)
    end
    
  end
   
end