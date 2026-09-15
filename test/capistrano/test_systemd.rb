# frozen_string_literal: true

require "test_helper"

class Capistrano::Cable::TestSystemd < Minitest::Test
  Role = Struct.new(:hostname, :user, :properties)

  # The service template shells out to read the bundle command, which needs a
  # connection we don't have in tests.
  class Plugin < Capistrano::Cable::Systemd
    def expanded_bundle_command
      "/usr/bin/bundle"
    end
  end

  def setup
    Capistrano::Configuration.reset!
    set(:application, "myapp")
    set(:stage, "production")
    set(:deploy_to, "/home/myapp/public_html")
    set(:default_env, {})
  end

  def test_default_bind_is_a_unix_socket_in_the_shared_directory
    assert_equal ["unix:///home/myapp/public_html/shared/tmp/sockets/cable.sock"],
      plugin.cable_binds.map(&:to_s)
  end

  def test_puma_listens_on_every_configured_bind
    options = plugin(cable_bind: ["unix:///tmp/cable.sock", "tcp://0.0.0.0:28090"]).puma_options

    assert_includes options, "--bind 'unix:///tmp/cable.sock'"
    assert_includes options, "--bind 'tcp://0.0.0.0:28090'"
    refute_includes options, "--port"
  end

  def test_socket_directories_are_only_needed_by_unix_binds
    assert_equal ["/var/run/myapp"],
      plugin(cable_bind: ["unix:///var/run/myapp/cable.sock", "tcp://0.0.0.0:28090"]).cable_socket_dirs
  end

  def test_removed_options_stop_the_install
    error = assert_raises(ArgumentError) { plugin(cable_port: 28090).check_removed_options! }

    assert_includes error.message, ":cable_port is not supported anymore"
    assert_includes error.message, 'set :cable_bind, "tcp://0.0.0.0:<port>"'
  end

  def test_supported_options_let_the_install_run
    assert_nil plugin.check_removed_options!
  end

  def test_units_are_installed_at_every_deploy_before_the_server_is_restarted
    Rake::Task.clear
    ran = []
    Rake::Task.define_task("deploy:finished")
    Rake::Task.define_task("cable:install") { ran << "install" }
    Rake::Task.define_task("cable:smart_restart") { ran << "smart_restart" }

    plugin.register_hooks
    Rake::Task["deploy:finished"].invoke

    assert_equal ["install", "smart_restart"], ran
  end

  def test_socket_unit_listens_on_every_bind
    unit = render("cable.socket", cable_bind: ["unix:///tmp/cable.sock", "unix:///tmp/other.sock"])

    assert_includes unit, "ListenStream=/tmp/cable.sock\n"
    assert_includes unit, "ListenStream=/tmp/other.sock\n"
    refute_includes unit, "NoDelay"
  end

  def test_socket_unit_disables_nagle_algorithm_on_tcp_binds
    assert_includes render("cable.socket", cable_bind: "tcp://0.0.0.0:28090"), "NoDelay=true"
  end

  def test_service_unit_waits_for_its_socket_unit
    unit = render("cable.service")

    assert_includes unit, "Requires=myapp_cable_production.socket\n"
    assert_includes unit, "After=syslog.target network.target myapp_cable_production.socket\n"
  end

  def test_service_unit_ignores_the_socket_unit_when_it_is_disabled
    unit = render("cable.service", cable_enable_socket_service: false)

    refute_includes unit, "myapp_cable_production.socket"
    assert_includes unit, "After=syslog.target network.target\n"
  end

  def test_service_unit_starts_puma_on_the_configured_bind
    unit = render("cable.service", cable_bind: "unix:///tmp/cable.sock")

    assert_includes unit, "ExecStart=/usr/bin/bundle exec puma --no-config --bind 'unix:///tmp/cable.sock'"
  end

  private

  def set(key, value)
    Capistrano::Configuration.env.set(key, value)
  end

  def plugin(options = {})
    options.each { |key, value| set(key, value) }
    Plugin.new.tap(&:set_defaults)
  end

  def render(template, options = {})
    plugin(options)
      .compiled_template_cable(template, Role.new("example.com", "deploy", {}))
      .read
  end
end
