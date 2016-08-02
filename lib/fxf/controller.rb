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
      thread << Thread.new {
        puts "Update Thread initiated!!! Fetching Previews"
          self.update_preview
      }
      self.cleanup
      #self.dump_config
    end
    def dump_config
        #self.cam.device.config["viewfinder"] = true
        #puts self.cam.device.config.to_json
    end
    def cleanup
        @cleaner = FXF::Cleaner.new({
            cam: cam,
            delete: true,
            output: true
          })
          @cleaner.cleanup
          puts "Cleanup run started"
    end
    def end_it 
      shutdown=true
    end
    def capture
      temp = nil
      @mutex.synchronize do
        temp =  self.cam.device.capture;
      end
      sleep 3
      
      return temp
    end
    def update_preview
      
      while true
          sleep 0.5
          @mutex.synchronize do
            self.preview = self.cam.device.preview.data
          end
          if shutdown 
            break
          end
      end
      
    rescue => error
      
      puts "HARD ERROR #{error.inspect}"
      Process.kill('KILL', Process.pid)  
      
      
    end
    
    
end
end