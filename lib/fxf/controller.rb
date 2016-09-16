require 'get_process_mem'

module FXF
  class Controller
    attr_accessor :cam
    attr_accessor :mutex
    attr_accessor :thread
    attr_accessor :preview
    attr_accessor :shutdown
    attr_accessor :cleaner
    def initialize
      self.mutex = Mutex.new
      self.cam = FXF::Cam.new
      self.preview = nil
      self.shutdown = false
      thread = []
      thread << Thread.new do
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

    def end_it
      shutdown = true
    end

    def capture
      temp = nil
      @mutex.synchronize do
        temp = cam.capture
      end
      sleep 3

      temp
    end

    def update_preview
      mem = GetProcessMem.new

      loop do
        sleep 0.5
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
