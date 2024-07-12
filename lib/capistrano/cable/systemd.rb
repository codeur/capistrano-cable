require "capistrano/plugin"
require_relative "bind"

module Capistrano
  module Cable
    class Systemd < Capistrano::Plugin
      def register_hooks
        after "deploy:finished", "cable:smart_restart"
      end

      def define_tasks
        eval_rakefile File.expand_path("../../tasks/systemd.rake", __FILE__)
      end

      def set_defaults
        set_if_empty :cable_role, :web
        set_if_empty :cable_port, 29292
        set_if_empty :cable_dir, -> { File.join(release_path, "cable") }
        set_if_empty :cable_pidfile, -> { File.join(shared_path, "tmp", "pids", "cable.pid") }
        set_if_empty :cable_env, -> { fetch(:rack_env, fetch(:rails_env, fetch(:stage))) }
        set_if_empty :cable_access_log, -> { File.join(shared_path, "log", "cable.access.log") }
        set_if_empty :cable_error_log, -> { File.join(shared_path, "log", "cable.error.log") }

        # Chruby, Rbenv and RVM integration
        append :chruby_map_bins, "puma", "pumactl" if fetch(:chruby_map_bins)
        append :rbenv_map_bins, "puma", "pumactl" if fetch(:rbenv_map_bins)
        append :rvm_map_bins, "puma", "pumactl" if fetch(:rvm_map_bins)

        # Bundler integration
        append :bundle_bins, "puma", "pumactl"

        set_if_empty :cable_systemctl_bin, -> { fetch(:systemctl_bin, "/bin/systemctl") }
        set_if_empty :cable_service_unit_name, -> { "#{fetch(:application)}_cable_#{fetch(:stage)}" }
        set_if_empty :cable_enable_socket_service, false
        set_if_empty :cable_socket_unit_name, -> { "#{fetch(:application)}_cable_#{fetch(:stage)}.socket" }
        # set_if_empty :cable_bind, -> { "unix:/tmp/#{fetch(:app_domain)}.sock" }

        set_if_empty :cable_service_unit_env_files, -> { fetch(:service_unit_env_files, []) }
        set_if_empty :cable_service_unit_env_vars, -> { fetch(:service_unit_env_vars, []) }

        set_if_empty :cable_systemctl_user, -> { fetch(:systemctl_user, :user) }
        set_if_empty :cable_enable_lingering, -> { fetch(:cable_systemctl_user) != :system }
        set_if_empty :cable_lingering_user, -> { fetch(:lingering_user, fetch(:user)) }

        set_if_empty :cable_service_templates_path, fetch(:service_templates_path, "config/deploy/templates")
      end

      def expanded_bundle_command
        backend.capture(:echo, SSHKit.config.command_map[:bundle]).strip
      end

      def fetch_systemd_unit_path
        if fetch(:cable_systemctl_user) == :system
          "/etc/systemd/system/"
        else
          home_dir = backend.capture :pwd
          File.join(home_dir, ".config", "systemd", "user")
        end
      end

      def systemd_command(*args)
        command = [fetch(:cable_systemctl_bin)]

        unless fetch(:cable_systemctl_user) == :system
          command << "--user"
        end

        command + args
      end

      def sudo_if_needed(*command)
        if fetch(:cable_systemctl_user) == :system
          backend.sudo command.map(&:to_s).join(" ")
        else
          backend.execute(*command)
        end
      end

      def execute_systemd(*args)
        sudo_if_needed(*systemd_command(*args))
      end

      # From Common

      def cable_switch_user(role, &block)
        user = cable_user(role)
        if user == role.user
          block.call
        else
          backend.as user do
            block.call
          end
        end
      end

      def cable_user(role)
        properties = role.properties
        properties.fetch(:cable_user) || # local property for cable only
          fetch(:cable_user) ||
          properties.fetch(:run_as) || # global property across multiple capistrano gems
          role.user
      end

      def cable_bind
        Array(fetch(:cable_bind)).collect do |bind|
          "bind '#{bind}'"
        end.join("\n")
      end

      def service_unit_type
        ## Jruby don't support notify
        return "simple" if RUBY_ENGINE == "jruby"
        fetch(:cable_service_unit_type,
          ## Check if sd_notify is available in the bundle
          Gem::Specification.find_all_by_name("sd_notify").any? ? "notify" : "simple")
      end

      def puma_options
        options = []
        options << "--no-config"
        # options << "--dir #{fetch(:cable_dir)}" if fetch(:cable_dir) # or change WorkingDirectory in cable.service?
        if fetch(:cable_ssl_certificate) && fetch(:cable_ssl_certificate_key)
          options << "--bind 'ssl://0.0.0.0:#{fetch(:cable_port)}?key=#{fetch(:cable_ssl_certificate_key)}&cert=#{fetch(:cable_ssl_certificate)}'"
          # Can use: &verify_mode=none&ca=...
        end
        options << "--environment #{fetch(:cable_env)}"
        # options << "--port #{fetch(:cable_port)}"
        options << "--pidfile #{fetch(:cable_pidfile)}" if fetch(:cable_pidfile)
        options << "--threads #{fetch(:cable_threads)}" if fetch(:cable_threads)
        options << "--workers #{fetch(:cable_workers)}" if fetch(:cable_workers)
        options.join(" ")
      end

      def compiled_template_cable(from, role)
        @role = role
        file = [
          "lib/capistrano/templates/#{from}-#{role.hostname}-#{fetch(:stage)}.rb",
          "lib/capistrano/templates/#{from}-#{role.hostname}.rb",
          "lib/capistrano/templates/#{from}-#{fetch(:stage)}.rb",
          "lib/capistrano/templates/#{from}.rb.erb",
          "lib/capistrano/templates/#{from}.rb",
          "lib/capistrano/templates/#{from}.erb",
          "config/deploy/templates/#{from}.rb.erb",
          "config/deploy/templates/#{from}.rb",
          "config/deploy/templates/#{from}.erb",
          File.expand_path("../../templates/#{from}.erb", __FILE__),
          File.expand_path("../../templates/#{from}.rb.erb", __FILE__)
        ].detect { |path| File.file?(path) }
        erb = File.read(file)
        StringIO.new(ERB.new(erb, trim_mode: "-").result(binding))
      end

      def upload_template_cable(from, to, role)
        backend.upload! compiled_template_cable(from, role), to
      end

      def cable_binds
        Array(fetch(:cable_bind)).map do |m|
          etype, address = /(tcp|unix|ssl):\/{1,2}(.+)/.match(m).captures
          Bind.new(m, etype.to_sym, address)
        end
      end
    end
  end
end
