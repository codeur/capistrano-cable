# frozen_string_literal: true

module Capistrano
  module Cable
    # A Puma bind, as given to `set :cable_bind`:
    #
    #   unix:///home/app/shared/tmp/sockets/cable.sock
    #   tcp://0.0.0.0:28090
    #   ssl://0.0.0.0:28090?cert=/path/cert.pem&key=/path/key.pem
    #
    # `address` is the part systemd needs for its `ListenStream`: Puma matches
    # the socket handed over by systemd against its own binds by address, so
    # both have to be written exactly the same way.
    class Bind
      SCHEMES = %w[tcp ssl unix].freeze

      attr_reader :address

      def initialize(bind)
        @bind = bind.to_s
        scheme, rest = @bind.split(":", 2)
        @scheme = scheme
        @address = rest.to_s.delete_prefix("//").split("?").first.to_s

        raise ArgumentError, "Unsupported cable_bind #{@bind.inspect}, expected #{SCHEMES.join("://, ")}://" unless SCHEMES.include?(@scheme)
        raise ArgumentError, "Empty address in cable_bind #{@bind.inspect}" if @address.empty?
        raise ArgumentError, "cable_bind #{@bind.inspect} needs an absolute socket path" if unix? && !@address.start_with?("/")
      end

      def unix?
        @scheme == "unix"
      end

      def to_s
        @bind
      end
    end
  end
end
