module FXF
  class Queue
    attr_accessor :config
    def initialize(config = {})
      @config = config
      thread = []
      thread << Thread.new do
        upload_queue
      end
    end

    def upload_queue
      puts 'STARTING QUEUE WORKER'
      loop do
        puts "QUEUE RUN"
        elements = Dir['QUEUE/WAIT/*']
        elements.each do | job |
          
          puts "DOING JOB #{job}"
          file = File.read(job)
          data_hash = JSON.parse(file)
          r = RestClient.post('https://api.willi.krone.at/postbox',{:picbox_obj =>  data_hash["picbox_obj"], :picbox_data => data_hash["picbox_data"], :multipart => true});
          resp = JSON.parse(r.body)
          if resp["missionId"]
            FileUtils.mv(job, "QUEUE/DONE")
            puts "DONE UPLOAD"
          end
          sleep @config["queue"]["per_item_pause"]
        end
        sleep sleep @config["queue"]["per_run_pause"]
      end
    end
  end
end
