require 'socket'

module Moneta
  module Adapters
    class Client < Base
      include Server::Util

      def initialize(options = {})
        @socket = options[:file] ? UNIXSocket.open(options[:file]) :
          TCPSocket.open(options[:host] || '127.0.0.1', options[:port] || Server::DEFAULT_PORT)
      end

      def key?(key, options = {})
        write(@socket, [:key?, key, options])
        read(@socket)
      end

      def load(key, options = {})
        write(@socket, [:load, key, options])
        read(@socket)
      end

      def store(key, value, options = {})
        write(@socket, [:store, key, value, options])
        value
      end

      def delete(key, options = {})
        write(@socket, [:delete, key, options])
        read(@socket)
      end

      def clear(options = {})
        write(@socket, [:clear, options])
        self
      end

      def close
        @socket.close
        nil
      end
    end
  end
end
