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
      sleep 0.5
      
      
    end
    def capture
      

      puts "SHOT SET"
      set_config("shot");
      #puts "SHOT"


      device.trigger
      puts "triggered"
      cap = device.wait_for(:file_added)
      puts "waited"
      puts "SHOTTED"

      random_key=(0...12).map { (65 + rand(26)).chr }.join
      cap.data.save "public/#{random_key}.jpg"

       #cap = device.capture
       #cap.data.save "public/#{random_key}.jpg"


      set_config("preview");
      puts "PREVIEW SET"
      random_key
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
      
      camera = GPhoto2::Camera.first
      camera.exit
      port = GPhoto2::Port.new
      port.info = camera.port_info
      port.open
      port.reset
      port.close
      camera.close
      
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
