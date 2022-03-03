require 'socket'
require 'rack'
require 'forwardable'
require 'stringio'
require 'pry'

module WebTrash

  class HTTPServer
    def initialize(port: 8080)
      @port = port
      @server = TCPServer.new @port
    end

    def run!(app)
      while conn = Connection.new(@server.accept)
        begin
          env = conn.request.to_env(port: @port, scheme: 'http')
          conn.response app.call(env)
        rescue => e
          # типа лог
          puts "Упали((( #{e} )))"
        ensure
          conn.close
        end
      end
    end
  end

  class Connection
    extend Forwardable

    def initialize(conn)
      @conn = conn
    end

    def request
      return @req if @req

      method, url, _ = @conn.gets.split
      path, query_string = url.split(??, 2)

      @req = Request.new(
        method,
        URL.new(url, path, query_string),
        read_headers,
        read_body
      )
    end

    def response(res)
      res = Response.new(*res) if res.kind_of? Array
      @conn.puts res.to_http
    end

    def_delegators :@conn, :close, :closed?

    private

    def read_headers
      headers = Headers.new
      until (header = @conn.gets) == "\r\n"
        headers << header; end
      @headers = headers
    end

    def read_body
      if len = @headers['Content-Length']&.to_i
        @conn.read len
      end
    end
  end

  URL = Struct.new :url, :path, :query_string
  Request = Struct.new(:mthd, :url, :headers, :body) do
    def to_env(**opts)
      {
        'REQUEST_METHOD' => self.mthd,
        'SCRIPT_NAME' => '',
        'PATH_INFO' => self.url.path,
        'QUERY_STRING' => self.url.query_string || '',
        'SERVER_NAME' => 'trash', # изменить на константу
        'SERVER_PORT' => opts[:port],
        # rack
        'rack.version' => Rack::VERSION,
        'rack.url_scheme' => opts[:scheme],
        'rack.input' => StringIO.new(body || ''),
        'rack.errors' => $stderr,
        # and more....
      }
    end
  end

  Response = Struct.new(:code, :headers, :body) do
    Codes = { 200 => 'OK' }

    def to_http
      body = self.body.join
      [
        "HTTP/1.1 #{code} #{Codes[code]}\r\n",
        self.headers.map{|k,v| "#{k}: #{v}\r\n"}.join,
        "Content-Type: text/html\r\n",
        "Content-Length: #{body.length}\r\n\r\n",
        body
      ].join
    end

    alias to_s to_http
  end

  class Headers
    extend Forwardable

    def initialize
      @hash = {}
    end

    def <<(header)
      k, v = header.chomp.split(?:, 2)
      @hash[k] = v
    end

    def_delegators :@hash, :[], :inspect, :to_s
  end

end

module Rack::Handler
  module Trash
    def self.run(app, opts = {})
      WebTrash::HTTPServer.new.run! app
    end
  end

  register 'trash', 'Rack::Handler::Trash'
end
