module FXF
  
class Cam
  attr_accessor :device
  def initialize
    puts 'FXF Cam init'
    init_cam
  end

  def died
    # init_cam
    device.close unless device.nil?
  end

  def init_cam
    # while true  do

    `killall -9 PTPCamera` if OS.mac?
    device.close unless device.nil?
    self.device = GPhoto2::Camera.first
    
    file = File.read('cam-config.json')
    data_hash = JSON.parse(file)

    puts "found Camera #{device.model} - apply config"
    device.config.merge(data_hash)
    device.save
    puts "Config applied!!"
    self.device.reload
    data = device.preview.data
    device.update(autofocusdrive: true)
    #do a dummy preview
    
  #      break
  rescue => error
    puts "Camera cannot be initiated - retry'ing #{error.inspect}"
    sleep 2
    exit

    # end
  end
end

end