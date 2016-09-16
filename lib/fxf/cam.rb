module FXF
  class Cam
    attr_accessor :device
    attr_accessor :preview_config
    attr_accessor :shot_config
    def initialize
      puts 'FXF Cam init'
      init_cam
    end
    def set_config(wich)
      if(wich == "shot") 
        cfg = self.shot_config
      else
        cfg = self.preview_config
      end
      device.close unless device.nil?
      self.device = GPhoto2::Camera.first
      device.update(cfg)
      
      
    end
    def capture
      
      set_config("shot");
      puts "SHOT SET"
      cap = device.capture
      puts "SHOTTED"
      
      r = cap.data.dup
      
      
      
      
      set_config("preview");
      puts "PREVIEW SET"
      puts "PIC LENGTH: #{r.length}" 
      r
    
    end
    def reopen
      
    end
    def died
      # init_cam
      device.close unless device.nil?
    end

    def init_cam
      # while true  do

      `killall -9 PTPCamera` if OS.mac?
      
      
      
      preview_file = File.read('cam-config.json')
      @preview_config = JSON.parse(preview_file)

      shot_file = File.read('cam-config-shot.json')
      @shot_config = JSON.parse(shot_file)

      set_config("preview");
      
      data = device.preview.data
      
      
    rescue => error
      puts "Camera cannot be initiated - retry'ing #{error.inspect}"
      sleep 2
      exit

      # end
    end
  end
end
