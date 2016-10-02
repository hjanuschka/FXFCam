require 'gphoto2'
require 'json'
require 'os'
require 'base64'
require 'mini_magick'
require 'open-uri'
require 'rqrcode'
require 'cupsffi'
require 'fileutils'
require 'rest-client'
require 'sinatra/directory_listing'

require './lib/fxf/controller.rb'
require './lib/fxf/cam.rb'
require './lib/fxf/queue.rb'
require './lib/fxf/cleaner.rb'
require './lib/fxf/camconfig.rb'
require './lib/fxf/coin_acceptor.rb'

config_file = File.read('config.json')
config = JSON.parse(config_file)

controller = FXF::Controller.new(config) if config["has_cam"]

queue_worker = FXF::Queue.new


coin_acceptor = nil
if config["has_coin_acceptor"]
  coin_acceptor = FXF::CoinAcceptor.new(config)
end


at_exit do
  controller.exit_cam
end


require 'sinatra'

set :threaded, false
set :port, 8888
set :bind, '0.0.0.0'
set :server, :thin
disable :logging
set :protection, except: :json_csrf


get '/coins/remove' do
  headers 'Access-Control-Allow-Origin' => '*'
  content_type :json
  if coin_acceptor.get_credit > 0
    coin_acceptor.remove_credit(params[:amount].to_i)
  end
  return {"credit" => coin_acceptor.get_credit}.to_json
end
get '/coins/add' do
  headers 'Access-Control-Allow-Origin' => '*'
  content_type :json
  coin_acceptor.add_credit(params[:amount].to_i)
  
  return {"credit" => coin_acceptor.get_credit}.to_json
end
get '/coins/current' do
  headers 'Access-Control-Allow-Origin' => '*'
  content_type :json
  return {"credit" => coin_acceptor.get_credit}.to_json
end

get '/liveview' do
  boundary = 'some_shit'
  headers \
    'Cache-Control' => 'no-cache, private',
    'Pragma'        => 'no-cache',
    'Content-type'  => "multipart/x-mixed-replace; boundary=#{boundary}"

  stream(:keep_open) do |out|
    loop do
      content = controller.preview

      out << "Content-type: image/jpeg\n\n"
      out << content
      out << "--#{boundary}"

      sleep @config["preview_interval"]
    end
  end
end

# REST INTERFACE
post '/capture' do
  #Captures with received config
  headers 'Access-Control-Allow-Origin' => '*'
  content_type :json
  return_message = {}
  config_to_test = {}
  update_type = "preview"
  
  params.keys.each do | e  |
    if e == "type"
      update_type=params[e]
      next
    end
    config_to_test[e]=params[e];
  end
  
  if !config["has_cam"]
    picdata = {"image" => 'default', "duration" => 5}
    sleep 5
  else
    picdata = controller.capture(config_to_test)
  end
  
  return_message[:status] = 'success'
  return_message[:cca_response] = { data: { image: picdata["image"], duration: picdata["duration"] } }
  return_message.to_json
end
get '/capture' do
  headers 'Access-Control-Allow-Origin' => '*'
  content_type :json
  return_message = {}
  begin
    headers('Content-Type' => 'application/json')

    if !config["has_cam"]
      picdata = {"image" => 'default', "duration" => 5}
      sleep 5
    else
      picdata = controller.capture
    end
    
    return_message[:status] = 'success'
    return_message[:cca_response] = { data: { image: picdata["image"], duration: picdata["duration"] } }
    return_message.to_json
  rescue => error
    puts error.backtrace
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
  controller.cam.device.config.to_json
end
post '/postbox' do
  headers 'Access-Control-Allow-Origin' => '*'
  binary_pic = IO.binread("public/#{params[:picbox_data]}.jpg")
  b64_pic = Base64.encode64(binary_pic)
  params['picbox_data'] = "data:image/jpg;base64,#{b64_pic}"

  json_doc = params
  # Store it to Queue

  file = Tempfile.new(['queue', '.json'])
  file << json_doc.to_json
  file.flush
  FileUtils.mv(file.path, 'QUEUE/WAIT/')
  file.close

  headers('Content-Type' => 'application/json')
  return { 'asdasd' => 123 }.to_json
end
get '/edit_config' do
  if params["mode"] == nil
    params["mode"]="preview"
  end
  #tmp = controller.get_current_config
  options_to_find = {
          "iso" => {"current" => 400, "avail"=>[200,800,300]},
          "shutterspeed" =>  {"current" => 400, "avail"=>["asdf","1/160","ASdaf1"]}
          
  }; 
  @current = options_to_find
  @current = controller.get_current_config
  @config = config
  @mode = params["mode"]
  erb :config_editor
end

post '/set_config' do
  config_to_store = {}
  update_type = "preview"
  
  params.keys.each do | e  |
    if e == "type"
      update_type=params[e]
      next
    end
    config_to_store[e]=params[e];
  end
  
  
  
  config[update_type]=config_to_store;
  pretty_config = JSON.pretty_generate(config);
  File.write("config.json", pretty_config)
  return pretty_config
  
end

get '/focus' do
  headers 'Access-Control-Allow-Origin' => '*'
  controller.focus
  #sleep 1
  headers('Content-Type' => 'image/jpeg')
  if !config["has_cam"]
    File.read('default.jpg')
  else
    controller.preview
  end
  
  
end
post '/print_image' do
  headers 'Access-Control-Allow-Origin' => '*'
  b64 = params[:b64]
  watermark = params[:watermark]
  qr = params[:qr]
  decode_base64_content = IO.binread("public/#{b64}.jpg")

  # Fetch Willi Logo
  willifile = Tempfile.new(['willi', '.png'])
  download = open('https://www.willi.krone.at/willi-logo@2x.png')
  IO.copy_stream(download, willifile)

  unless watermark.nil?
    # Fetch Watermark
    watermarkfile = Tempfile.new(['watermark', '.png'])
    download = open(watermark)
    IO.copy_stream(download, watermarkfile.path)
  end

  unless qr.nil?
    qrfile = Tempfile.new(['qr', '.png'])
    # generate QR
    qrcode = RQRCode::QRCode.new(qr)
    # With default options specified explicitly
    png = qrcode.as_png(
      resize_gte_to: false,
      resize_exactly_to: false,
      fill: 'white',
      color: 'black',
      module_px_size: 5,
      file: nil # path to write
    )
    IO.write(qrfile.path, png.to_s)
  end

  img = MiniMagick::Image.open("public/#{b64}.jpg")

  img.resize '1200x'

  unless watermark.nil?
    # add watermark

    img.combine_options do |c|
      c.gravity 'SouthEast'
      c.draw "image Over 20,20 0,0 '#{watermarkfile.path}'"
    end
  end

  unless qr.nil?
    # add QR
    img.combine_options do |c|
      c.gravity 'SouthWest'
      c.draw "image Over 20,20 0,0 '#{qrfile.path}'"
    end
  end

  # add Willi
  img.combine_options do |c|
    c.gravity 'NorthEast'
    c.draw "image Over 20,20 70,70 '#{willifile.path}'"
  end

  file = Tempfile.new(['picbox', '.jpg'])

  # img.write('8.jpg')
  a = img.write(file.path)

  # `lpr -o landscape -o fit-to-page -o media=Custom.4x6 #{file.path}`
  printers = CupsPrinter.get_all_printer_names
  printer = CupsPrinter.new(printers.first)
  job = printer.print_file(file.path, 'PageSize' => 'w288h432', 'StpiShrinkOutput' => 'Expand', 'ColorModel' => 'RGB')

  puts "printing #{job.inspect}"

  File.unlink(file.path)
  File.unlink(qrfile.path) unless qr.nil?
  File.unlink(watermarkfile.path) unless watermark.nil?
  File.unlink(willifile.path)
  'DONE'
end
get '/preview' do
  headers 'Access-Control-Allow-Origin' => '*'
  return_message = {}
  begin
    headers('Content-Type' => 'image/jpeg')
    if !config["has_cam"]
      File.read('default.jpg')
    else
      controller.preview
    end

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

get '*' do |path|
  if File.exist?(File.join(settings.public_folder, path))
    if File.directory?(File.join(settings.public_folder, path))
      list()
    else
      send_file File.join(settings.public_folder, path)
    end
  else
    "Not Found"
  end
end
