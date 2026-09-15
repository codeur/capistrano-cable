# frozen_string_literal: true

require "test_helper"

class Capistrano::Cable::TestBind < Minitest::Test
  def test_unix_bind_keeps_its_absolute_path
    ["unix:///app/shared/tmp/sockets/cable.sock", "unix:/app/shared/tmp/sockets/cable.sock"].each do |bind|
      assert_equal "/app/shared/tmp/sockets/cable.sock", Capistrano::Cable::Bind.new(bind).address
      assert Capistrano::Cable::Bind.new(bind).unix?
    end
  end

  def test_tcp_bind_address_is_host_and_port
    bind = Capistrano::Cable::Bind.new("tcp://0.0.0.0:28090")

    assert_equal "0.0.0.0:28090", bind.address
    refute bind.unix?
  end

  def test_ssl_bind_address_drops_the_certificate_options
    bind = Capistrano::Cable::Bind.new("ssl://0.0.0.0:28090?cert=/path/cert.pem&key=/path/key.pem")

    assert_equal "0.0.0.0:28090", bind.address
    refute bind.unix?
  end

  def test_bind_keeps_the_whole_string_for_puma
    bind = "ssl://0.0.0.0:28090?cert=/path/cert.pem&key=/path/key.pem"

    assert_equal bind, Capistrano::Cable::Bind.new(bind).to_s
  end

  def test_unsupported_scheme_is_rejected
    error = assert_raises(ArgumentError) { Capistrano::Cable::Bind.new("http://0.0.0.0:28090") }

    assert_includes error.message, "Unsupported cable_bind"
  end

  def test_address_less_bind_is_rejected
    assert_raises(ArgumentError) { Capistrano::Cable::Bind.new("unix://") }
  end

  def test_relative_socket_path_is_rejected
    error = assert_raises(ArgumentError) { Capistrano::Cable::Bind.new("unix://cable.sock") }

    assert_includes error.message, "absolute socket path"
  end
end
