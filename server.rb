require 'gphoto2'
require 'sinatra'
require 'json'
require 'os'
require 'base64'
require 'mini_magick'
require 'open-uri'
require 'rqrcode'
require 'cupsffi'

require './lib/fxf/controller.rb'
require './lib/fxf/cam.rb'
require './lib/fxf/cleaner.rb'

set :port, 8888
set :bind, '0.0.0.0'
set :server, :thin
disable :logging

preview = FXF::Controller.new if ENV['ONLY_PRINT'].nil?

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
post '/print_image' do
  b64 = params[:b64]
  watermark = params[:watermark]
  qr = params[:qr]
  decode_base64_content = Base64.decode64(b64.split('base64,').last)

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

  img = MiniMagick::Image.read(decode_base64_content)

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
