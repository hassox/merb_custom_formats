Merb::Router.extensions do
  
  # Wrap your routes 
  def custom_formats(*formats, &block)
    p = Proc.new do |request, params|
      if params[:format]
        params
      else
        formats_to_run = if formats.empty?
          Merb::CustomFormats.router_procs.keys
        else
          Merb::CustomFormats.router_procs.keys & [*formats]
        end
      
        r = formats_to_run.detect do |format| 
          Merb::CustomFormats.router_procs[format].call(request, params)
        end
        params[:format] = r unless r.blank?
        params
      end    
    end
    defer(p, &block)
  end  
  
end