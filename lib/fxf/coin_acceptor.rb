module FXF
  class CoinAcceptor
    require 'serialport'
    attr_accessor :config
    attr_accessor :mutex
    attr_accessor :thread
    attr_accessor :credits
    def initialize(config = {})
      self.mutex = Mutex.new
      @config = config
      self.credits = 0
      self.thread = []
      self.thread << Thread.new do
        handle_coins
      end
      
    end
    def get_credit
      @mutex.synchronize do
        return self.credits
      end
    end
    def reset_credit
      @mutex.synchronize do
        self.credits=0
      end
    end
    def add_credit(amount = 0)
      @mutex.synchronize do
        self.credits += amount
      end
    end
    def remove_credit(amount = 0)
      @mutex.synchronize do
        self.credits -= amount;
      end
    end
    def handle_coins
      
      serial_port = SerialPort.new @config["has_coin_acceptor"]["device"], 9600, 8, 1, SerialPort::NONE
      loop do
              
                r = serial_port.read(1)
                add_credit(@config["has_coin_acceptor"]["cent_per_signal"])
                puts "Credits: #{self.credits}"
                
      end
    end
  end
end
