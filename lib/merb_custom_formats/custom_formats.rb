module Merb
  # Proivdes simple setup for custom formats in merb.  You can use Merb::CustomFormats as a descriptive 
  # way to configure new mime types in merb.  The plugin also provides a way for you to execute arbitrary logic
  # easily to set your format from any information available in the request.
  # 
  # ===Example
  #
  # To declare a new mime type simply add it and declare which mime_types are acceptable for the format
  #
  #     Merb::CustomFormats.add(:iphone) do
  #       mime_types "application/xhtml+xml"
  #     end
  #
  # This will setup the :iphone format for use in Merb via 
  #     provides :iphone
  #
  # The only required step is to declare the +mime_types+ but you can also specify the 
  # default response headers, transform (serialization) method, quality and a custom format selector.
  # By default the transform_method is +:"to_#{format}"+
  #
  # Here's an example showing all things in play
  # 
  #     Merb::CustomFormats.add(:iphone) do
  #       mime_types        "application/xhtml+xml", "text/xml"
  #       transform_method  :to_iphone_data
  #       headers           :some => "default header"
  #       quality           0.45
  #       selector do |request, route_params|
  #         request.user_agent && request.user_agent =~ /iphone/i
  #       end
  #     end
  #
  #  You can see here that there are multiple mime_types being set, custom transform method, etc.  
  #
  # The selector is a block that is run in the router as arbitrary logic to determine if the format matches
  # By returning true, you're asserting a match, and params[:format] and therefore content_type will be (in this case)
  # :iphone  If on the other hand you return false, the next custom format selector will be tried.  
  # You don't have to provide a selector, and if you don't, a normal mime type will be added to merb.
  #
  # To use in the router, just add a custom_format block around the routes you want to apply it to
  # 
  # ====Router Example
  #
  #     Merb::Router.prepare do
  #       custom_formats do
  #         resources :iphone_resources
  #         match("/foo").to(:controller => "bar")
  #       end
  #       resources :non_iphone_resources
  #     end
  #
  # This will check the format on the +:iphone_resources route+, and also the "/foo" route.  I will not try to match the 
  # custom formats on the +:non_iphone_resources+ routes.
  
  class CustomFormats
    # These are used to help track which formats the Merb::CustomFormats has setup
    # :api: private
    cattr_accessor :router_procs, :custom_formats
    @@router_procs    = {}
    @@custom_formats  = []
    
    # Remove the custom formats that have been setup from merbs mime types.
    # and also from the Merb::CustomFormats. 
    # :api: public
    def self.clear_custom_formats!
      custom_formats.each{|f| Merb.remove_mime_type(f)}
      router_procs.clear
      custom_formats.clear
    end
    
    # Adds a custom format to Merb.  Use this method to add custom mime types to merb,
    # and also to add selectors to run inside the router.
    # :api: public
    def self.add(format, &block)
      f = Format.new(format, block)
      raise "You must specify mime_types for your custom format #{format.inspect}" if f.mime_types.blank?
      self.custom_formats << format
      self.router_procs[format] = f.selector if f.selector
      Merb.add_mime_type format, f.transform_method, f.mime_types, f.headers, f.quality
    end
    
    class Format
      # Setup a new Merb::CustomFormats::Format object by supplying the 
      # format, and a block inside to execute
      # :api: private
      def initialize(format, block)
        @format = format
        @mime_types = []
        self.instance_eval(&block)
      end
      
      # Set the transform (serialization) method for this mime type for use with
      # the +display+ helper
      # :api: public
      def transform_method(transform = nil)
        @transform ||= transform || :"to_#{@format}"
        @transform
      end     
      
      # Set the acceptable mime types for this format.  The first one declared will
      # be used as the response header also.  Please see Merb.add_mime_type for more information
      # :api: public
      def mime_types(*types)
        types.flatten.each do |t|
          @mime_types << t
        end
        @mime_types
      end
      alias_method :mime_type, :mime_types
      
      
      # Setup a selector to determine at runtime the format for a request.
      # The selector is a block that is run inside the router, and has access to the request, and
      # router params object.  
      #
      # ====Example
      #
      #    Merb::CustomFormats.add(:foo) do
      #      mime_types "foo"
      #      selector do |request, router_params|
      #        # return true in here to have :foo set, return false to move on
      #      end
      #    end
      # :api: public
      def selector(&block)
        @selector = block if block_given?
        @selector
      end
      
      # Set any custom default response headers that should be associated with this format.
      # Please see Merb.add_mime_type for more information
      # :api: public
      def headers(headers = {})
        @default_headers = headers if @default_headers.nil? || !headers.blank?
        @default_headers
      end
      
      # Set the quality for this mime type matching.  
      # Please see Merb.add_mime_type for more information
      # :api: public
      def quality(qual = nil)
        @quality = qual || 1 if @quality.nil?
        @quality
      end
    end
  end
end