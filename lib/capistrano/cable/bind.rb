module Capistrano
  module Cable
    class Bind < Struct.new(:full_address, :kind, :address)
      def unix?
        kind == :unix
      end

      def ssl?
        kind == :ssl
      end

      def tcp
        kind == :tcp || ssl?
      end

      def local
        if unix?
          self
        else
          self.class.new(
            localize_address(full_address),
            kind,
            localize_address(address)
          )
        end
      end

      private

      def localize_address(address)
        address.gsub(/0\.0\.0\.0(.+)/, "127.0.0.1\\1")
      end
    end
  end
end
