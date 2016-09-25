module FXF
  class CamConfig
    attr_accessor :cam
    def initialize(cam = nil)
      
      @cam = cam
    end
    def get_current
      options_to_find = {
              "iso" => {},
              "shutterspeed" => {},
              "aperture" => {},
              "focusmode" => {},
              "picturestyle" => {},
              "reviewtime" => {},
              "whitebalance" => {},
              "imageformat" => {},
              "capturetarget" => {},
              "colorspace" => {},
              "meteringmode" => {},
              
      }; 


       options_to_find.keys.each do |o|
         sett = available_options(o)
         options_to_find[o]["current"]=sett[:current];
         options_to_find[o]["avail"]=sett[:options];
         
       end
       return options_to_find
    end
    def available_options(_key = '')
      config_walk(@cam.window, _key)
    end

    def config_walk(widget, _key)
      if widget.type == :window || widget.type == :section
        a = false
        widget.children.each do |child|
          a = config_walk(child, _key)
          break if a != false
        end
        return a
      end

      if widget.name == _key
        case widget.type
        when :range
          range = widget.range
          step = range.size > 1 ? range[1] - range[0] : 1.0
          return "options2: #{range.first}..#{range.last}:step(#{step})"
        when :radio, :menu
          opts = widget.choices
          if _key == "focusmode"
            opts << "Manual"
          end
          return { options: opts, current: widget.value }
        else
          return ''
        end
      else
        return false
      end
    end
  end
end
