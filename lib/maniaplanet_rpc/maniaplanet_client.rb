require 'xmlrpc/xmlrpcs'

class ManiaplanetClient < XMLRPC::Client

  attr_accessor :protocol
  attr_accessor :socket
  attr_accessor :request_handle

  def initialize(ip, port)
    new_socket(ip, port)
  end

  def new_socket(ip, port)
    @socket = TCPSocket.new(ip, port)
    @request_handle = 0x80000000
    authenticate(@socket)
    @socket
  end

  def authenticate(socket)
    header = socket.recv(4).unpack("Vsize")

    if header[0] > 64
      raise Exception, "Wrong low-level protocol header!"
    end

    handshake = socket.recv(header[0])

    if handshake == "GBXRemote 1"
      @protocol = 1
    elsif handshake == "GBXRemote 2"
      @protocol = 2
    else
      raise Exception, "Unknown protocol version!"
    end
  end

  def read_response(socket)
    if protocol == 1
      content = socket.recv(4)
      if content.length == 0
        raise Exception, "Cannot read size!"
      end
      result = content.unpack("Vsize")
      size = result[0]
      receive_handle = request_handle
    else
      content = socket.recv(8)
      if content.length == 0
        raise Exception, "Cannot read size/handle!"
      end
      result = content.unpack("Vsize/Vhandle")
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
      response_length = response.length
    end
    response
  end

  def write_request(socket,request) # :doc:
    @request_handle = @request_handle + 1
    if protocol == 1
      bytes = [request.length, request].pack("Va*")
      socket.write(bytes)
    else
      bytes = [request.length, request_handle, request].pack("VVa*")
      socket.write(bytes)
    end
    socket.write bytes
  end

  def do_rpc( request, async )
    write_request(socket,request)
    read_response(socket)
  end

end