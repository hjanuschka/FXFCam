require 'get_process_mem'

module FXF
  class Controller
    attr_accessor :cam
    attr_accessor :mutex
    attr_accessor :thread
    attr_accessor :preview
    attr_accessor :shutdown
    attr_accessor :cleaner
    attr_accessor :thread
    attr_accessor :config
    
    
    def initialize(config = {})
      @config = config
      self.mutex = Mutex.new
      self.cam = FXF::Cam.new(config)
      self.preview = nil
      self.shutdown = false
      self.thread = []
      self.thread << Thread.new do
        puts 'Update Thread initiated!!! Fetching Previews'
        update_preview
      end
      cleanup
      # self.dump_config
    end

    def dump_config
      # self.cam.device.config["viewfinder"] = true
      # puts self.cam.device.config.to_json
    end

    def cleanup
      @cleaner = FXF::Cleaner.new(cam: cam,
                                  delete: true,
                                  output: true)
      @cleaner.cleanup
      puts 'Cleanup run started'
    end
    def exit_cam
      @mutex.synchronize do
        cam.exit_cam
      end
      
    end
    def end_it
      shutdown = true
    end
    def get_current_config
      temp = {}
      @mutex.synchronize do
        
        temp = cam.get_current_config
        
      end
      return temp
    end
    def focus
      @mutex.synchronize do
        
        temp = cam.focus
        
      end
    end
    def capture(capconf = nil)
      
      temp = nil
      @mutex.synchronize do
        temp = cam.capture(capconf)
      end

      {"image" => temp["image"], "duration" =>temp["duration"]}
    end

    def update_preview
      mem = GetProcessMem.new

      loop do
        sleep @config["preview_interval"]
        file = nil
        @mutex.synchronize do
          file = cam.device.preview
          self.preview = file.data
        end
        #file.release
        #puts mem.inspect
        break if shutdown
      end
    rescue => error
      puts error.backtrace
      puts "HARD ERROR #{error.inspect}"
      Process.kill('KILL', Process.pid)
    end
    end
end
