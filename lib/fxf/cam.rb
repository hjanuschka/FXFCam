module FXF
  class Cam
    attr_accessor :device
    attr_accessor :config
    def initialize(config = {})
      @config = config
      puts 'FXF Cam init'
      init_cam
    end

    def set_config(wich, capconf = nil)
      cfg = if wich == 'shot'
              @config['shot']
            else
              @config['preview']
            end
      device.close unless device.nil?
      self.device = GPhoto2::Camera.first

      cfg = capconf unless capconf.nil?

      device.update(cfg)
      # sleep 0.5
      sleep @config['settings_updated']
    end

    def focus
      set_config('preview')
      # device.update(eosremoterelease: @config["focus_press"])
      device.update(autofocusdrive: true)
      sleep @config['focus_max_time']
      puts 'Focus updated'
      set_config('preview')
    end

    def get_current_config
      cfg = FXF::CamConfig.new(@device)
      cfg.get_current
    end

    def capture(capconf = nil)
      
      startTime = Time.now
      if capconf.nil?
        set_config('shot')
        puts "SHOT SET"
      else
        set_config('custom', capconf)
        puts "CUSTOM SET"
      end
      device.trigger
      puts 'triggered'
      cap = device.wait_for(:file_added)
      endTime = Time.now
      puts 'waited'
      puts 'SHOTTED'

      random_key = (0...12).map { (65 + rand(26)).chr }.join
      cap.data.save "public/#{random_key}.jpg"

      # cap = device.capture
      # cap.data.save "public/#{random_key}.jpg"

      set_config('preview')
      puts 'PREVIEW SET'
      { 'image' => random_key, 'duration' => ((endTime - startTime)).round(1) }
    end

    def exit_cam
      puts 'CAM EXIT'
      device.close unless device.nil?
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
      begin
      camera = GPhoto2::Camera.first
      camera.exit
      port = GPhoto2::Port.new
      port.info = camera.port_info
      port.open
      port.reset
      port.close
      camera.close
    rescue => err
      puts err
    end

      set_config('preview')

      data = device.preview.data

    rescue => error
      puts "Camera cannot be initiated - retry'ing #{error.inspect}"
      puts error.backtrace
      sleep @config['usb_retry']
      exit

      # end
    end
  end
end
