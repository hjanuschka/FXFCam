module FXF
  class Cleaner
    attr_accessor :delete, :output,:cam
    # Recursively list folder contents with extended metadata.
    MAGNITUDES = %w(bytes KiB MiB GiB).freeze
    def initialize(params = {})
        @delete = params.fetch(:delete, false)
        @output = params.fetch(:output, true)
        @cam = params.fetch(:cam, nil)
    end
    def cleanup 
        visit(cam.device.filesystem)
    end
    def format_filesize(size, precision = 1)
      n = 0

      while size >= 1024.0 && n < MAGNITUDES.size
        size /= 1024.0
        n += 1
      end

      "%.#{precision}f %s" % [size, MAGNITUDES[n]]
    end
    def visit(folder)
      files = folder.files
      files.each do |file|
        info = file.info

        name = file.name
        # Avoid using `File#size` here to prevent having to load the data along
        # with it.
        size = format_filesize(info.size)
        mtime = info.mtime.utc.iso8601
        
        
        if @output
          puts "Deleting #{name}"
        end
        if @delete 
          
            file.delete
          
        end
        
          
      end
      folder.folders.each { |child| visit(child) }
      
    rescue => error
      
    
    end
  end
end
