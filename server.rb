require 'gphoto2'
require 'sinatra'
require 'json'
require 'os'
require 'base64'

class FXFCam
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
    puts "Camera found #{device.inspect}"
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

fxfcam = FXFCam.new

get '/liveview' do
  boundary = 'some_shit'
  headers \
     'Cache-Control' => 'no-cache, private',
     'Pragma'        => 'no-cache',
     'Content-type'  => "multipart/x-mixed-replace; boundary=#{boundary}"

  stream(:keep_open) do |out|
    loop do
      content = fxfcam.device.preview.data
      
      out << "Content-type: image/jpeg\n\n"
      out << content
      out << "--#{boundary}"
      
      sleep 0.5
    end
  end
end

set :port, 8888
set :server, :thin

# REST INTERFACE
get '/capture' do
  headers 'Access-Control-Allow-Origin' => '*'
  content_type :json
  return_message = {}
  begin
    headers('Content-Type' => 'application/json')
    pic = fxfcam.device.capture

    return_message[:status] = 'success'
    return_message[:cca_response] = { data: { image: Base64.encode64(pic.data) } }
    return_message.to_json
  rescue => error
    #fxfcam.died
    headers('Content-Type' => 'application/json')
    return_message[:status] = 'failed'
    return_message[:error] = true
    return_message[:code] = error.code
    return_message[:raw_msg] = error.message
    if error.code == -7 || error.code == -53
      puts "HARD ERROR #{error.message}"
      Process.kill('KILL', Process.pid)
    end
    return_message.to_json
  end
end
get '/preview' do
  return_message = {}
  begin
    headers('Content-Type' => 'image/jpeg')
    fxfcam.device.preview.data
  rescue => error
    #fxfcam.died
    headers('Content-Type' => 'application/json')
    return_message[:status] = 'failed'
    return_message[:error] = true
    return_message[:code] = error.code
    return_message[:raw_msg] = error.message
    # error -7 I/O error
    # error -53 Could not claim USB
    if error.code != -110 #-110 generic error - maybe no focus et all
      puts "HARD ERROR #{error.message}"
      Process.kill('KILL', Process.pid)
    end
    return_message.to_json
  end
end
