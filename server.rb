require 'gphoto2'
require 'sinatra'
require 'json'
require 'os'
require 'base64'

require './lib/fxf/controller.rb'
require './lib/fxf/cam.rb'
require './lib/fxf/cleaner.rb'

set :port, 8888
set :bind, '0.0.0.0'
set :server, :thin
disable :logging

preview = FXF::Controller.new

get '/liveview' do
  boundary = 'some_shit'
  headers \
    'Cache-Control' => 'no-cache, private',
    'Pragma'        => 'no-cache',
    'Content-type'  => "multipart/x-mixed-replace; boundary=#{boundary}"

  stream(:keep_open) do |out|
    loop do
      content = preview.preview

      out << "Content-type: image/jpeg\n\n"
      out << content
      out << "--#{boundary}"

      sleep 0.5
    end
  end
end

# REST INTERFACE
get '/capture' do
  headers 'Access-Control-Allow-Origin' => '*'
  content_type :json
  return_message = {}
  begin
    headers('Content-Type' => 'application/json')
    pic = preview.capture

    return_message[:status] = 'success'
    return_message[:cca_response] = { data: { image: Base64.encode64(pic.data) } }
    return_message.to_json
  rescue => error
    puts error.inspect
    # fxfcam.died
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
get '/config' do
  preview.cam.device.config.to_json
end
get '/preview' do
  return_message = {}
  begin
    headers('Content-Type' => 'image/jpeg')
    preview.preview
  rescue => error
    # fxfcam.died
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
