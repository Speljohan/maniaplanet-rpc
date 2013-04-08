require 'xmlrpc/client'

class ManiaplanetClient < XMLRPC::Client

  attr_accessor :request_handle, :ip, :port, :protocol

  def initialize(ip, port)
    @request_handle = 0x80000000
    @ip = ip
    @port = port
  end

  def new_socket(ip, port)
    socket = TCPSocket.new ip, port
    authenticate socket
    socket
  end

  def authenticate(socket)
    header = socket.recv(4).unpack "Vsize"

    if header[0] > 64
      raise Exception, "Wrong low-level protocol header!"
    end

    handshake = socket.recv header[0]

    if handshake == "GBXRemote 1"
      @protocol = 1
    elsif handshake == "GBXRemote 2"
      @protocol = 2
    else
      raise Exception, "Unknown protocol version!"
    end
  end

  def read_response(socket)
    response = ""
    loop do
      if protocol == 1
        content = socket.recv 4
        if content.bytesize == 0
          raise Exception, "Cannot read size!"
        end
        result = content.unpack "Vsize"
        size = result[0]
        receive_handle = @request_handle
      else
        content = socket.recv 8
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
        response << socket.recv(size - response_length)
        response_length = response.bytesize
      end

      if @request_handle - 0x80000000 != receive_handle
        # TODO: Add support for callbacks here.
      end


      break if @request_handle - 0x80000000 == receive_handle
    end
    response
  end

  def write_request(socket,request)
    @request_handle = @request_handle + 1
    if protocol == 1
      bytes = [request.bytesize, request].pack("Va*")
    else
      bytes = [request.bytesize, @request_handle, request].pack("VVa*")
    end
    socket.write bytes
  end

  def do_rpc(request, async) # TODO: Handle async requests
    if async
      Thread.new do
        sock = new_socket ip, port
        write_request sock, request
        read_response sock
      end
    else
      sock = new_socket ip, port
      write_request sock, request
      read_response sock
    end
  end

end