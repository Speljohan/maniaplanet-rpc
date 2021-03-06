require 'xmlrpc/client'
require 'thread'

module ManiaRPC
  class ManiaConnection

    include XMLRPC::ParserWriterChooseMixin

    def initialize(ip, port, callback)
      @callback = callback
      @request_handle = 0x80000000
      @ip = ip
      @port = port
      @send_queue = Queue.new
      begin
        @socket = TCPSocket.new ip, port
      rescue
        puts "Failed to establish a connection, is the ManiaPlanet server really running?"
        exit
      end
      @protocol = 0
      handshake
    end

    def handshake
      header = @socket.recv(4).unpack "Vsize"

      if header[0] > 64
        raise Exception, "Wrong low-level protocol header!"
      end

      handshake = @socket.recv header[0]

      if handshake == "GBXRemote 1"
        @protocol = 1
      elsif handshake == "GBXRemote 2"
        @protocol = 2
      else
        raise Exception, "Unknown protocol version!"
      end
    end

    def start
      loop do
        sleep(1.0/24.0)
        tick
      end
    end

    def call(method, *args)
      @request_handle = @request_handle + 1
      @send_queue.push [@request_handle, create().methodCall(method, *args)]
      @request_handle - 0x80000000
    end

    def tick
      write
      read
    end

    def read
      if IO.select([@socket], nil, nil, 0) != nil
        if @protocol == 1
          content = @socket.recv 4
          if content.bytesize == 0
            raise Exception, "Cannot read size!"
          end
          result = content.unpack "Vsize"
          size = result[0]
          receive_handle = @request_handle
        else
          content = @socket.recv 8
          if content.bytesize == 0
            raise Exception, "Cannot read size/handle!"
          end
          result = content.unpack "Vsize/Vhandle"
          size = result[0]
          receive_handle = result[1]
        end

        if receive_handle == 0 || size == 0
          raise Exception, "Connection interrupted!"
        end

        if size > 4096 * 1024
          raise Exception, "Response too large!"
        end

        response = ""
        response_length = 0

        while response_length < size
          response << @socket.recv(size - response_length)
          response_length = response.bytesize
        end

        begin # Response
          response = parser().parseMethodResponse(response)
          @callback.response_map[receive_handle].call response
        rescue Exception # Callback
          response = parser().parseMethodCall(response)
          @callback.parse_callback response
        end
      end
    end

    def write
      while @send_queue.length > 0
        request = @send_queue.pop
        if @protocol == 1
          bytes = [request[1].bytesize, request[1]].pack("Va*")
        else
          bytes = [request[1].bytesize, request[0], request[1]].pack("VVa*")
        end
        @socket.write bytes
      end
    end

  end

  ##
  # This class provides the interface for a ManiaPlanet Server by sending/receiving requests as well as callbacks.
  class ManiaClient

    attr_reader :connection
    attr_accessor :response_map

    def initialize(ip, port)
      @response_map = {}
      @callback_map = {}
      @connection = ManiaConnection.new ip, port, self
      Thread.new do
        @connection.start
      end
    end

    def parse_callback(message)
      @callback_map[message.first].call message
      @callback_map[:all].call message
    end

    ##
    # Call this with a block to handle a callback with the given name.
    def on(what, &block)
      @callback_map[what] = block
    end

    ##
    # Call this with a block to receive all callbacks. Can be used in conjunction with the on method.
    def all(&block)
      @callback_map[:all] = block
    end

    ##
    # Calls an RPC method with the given name and arguments, optionally handling the result within the passed block.
    # Note: The response is asynchronous.
    def call(method, *args, &block)
      if block_given?
        @response_map[@connection.call(method, *args)] = block
      else
        @response_map[@connection.call(method, *args)] = proc {}
      end
    end
  end
end