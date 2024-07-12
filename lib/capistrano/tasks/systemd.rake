# frozen_string_literal: true

git_plugin = self

namespace :cable do
  desc "Install Cable systemd service"
  task :install do
    on roles(fetch(:cable_role)) do |role|
      upload_compiled_template = lambda do |template_name, unit_filename|
        git_plugin.upload_template_cable template_name, "#{fetch(:tmp_dir)}/#{unit_filename}", role
        systemd_path = fetch(:cable_systemd_conf_dir, git_plugin.fetch_systemd_unit_path)
        if fetch(:cable_systemctl_user) == :system
          sudo "mv #{fetch(:tmp_dir)}/#{unit_filename} #{systemd_path}"
        else
          execute :mkdir, "-p", systemd_path
          execute :mv, "#{fetch(:tmp_dir)}/#{unit_filename}", systemd_path.to_s
        end
      end

      upload_compiled_template.call("cable.service", "#{fetch(:cable_service_unit_name)}.service")

      if fetch(:cable_enable_socket_service)
        upload_compiled_template.call("cable.socket", fetch(:cable_socket_unit_name))
      end

      # Reload systemd
      git_plugin.execute_systemd("daemon-reload")
      invoke "cable:enable"
    end
  end

  desc "Uninstall Cable systemd service"
  task :uninstall do
    invoke "cable:disable"
    on roles(fetch(:cable_role)) do |role|
      systemd_path = fetch(:cable_systemd_conf_dir, git_plugin.fetch_systemd_unit_path)
      if fetch(:cable_systemctl_user) == :system
        sudo "rm -f #{systemd_path}/#{fetch(:cable_service_unit_name)}*"
      else
        execute :rm, "-f", "#{systemd_path}/#{fetch(:cable_service_unit_name)}*"
      end
      git_plugin.execute_systemd("daemon-reload")
    end
  end

  desc "Enable Cable systemd service"
  task :enable do
    on roles(fetch(:cable_role)) do
      git_plugin.execute_systemd("enable", fetch(:cable_service_unit_name))
      git_plugin.execute_systemd("enable", fetch(:cable_socket_unit_name)) if fetch(:cable_enable_socket_service)

      if fetch(:cable_systemctl_user) != :system && fetch(:cable_enable_lingering)
        execute :loginctl, "enable-linger", fetch(:cable_lingering_user)
      end
    end
  end

  desc "Disable Cable systemd service"
  task :disable do
    on roles(fetch(:cable_role)) do
      git_plugin.execute_systemd("disable", fetch(:cable_service_unit_name))
      git_plugin.execute_systemd("disable", fetch(:cable_socket_unit_name)) if fetch(:cable_enable_socket_service)
    end
  end

  desc "Start Cable service via systemd"
  task :start do
    on roles(fetch(:cable_role)) do
      git_plugin.execute_systemd("start", fetch(:cable_service_unit_name))
    end
  end

  desc "Stop Cable service via systemd"
  task :stop do
    on roles(fetch(:cable_role)) do
      git_plugin.execute_systemd("stop", fetch(:cable_service_unit_name))
    end
  end

  desc "Stop Cable socket via systemd"
  task :stop_socket do
    on roles(fetch(:cable_role)) do
      git_plugin.execute_systemd("stop", fetch(:cable_socket_unit_name))
    end
  end

  desc "Restarts or reloads Cable service via systemd"
  task :smart_restart do
    if fetch(:cable_phased_restart)
      invoke "cable:reload"
    else
      invoke "cable:restart"
    end
  end

  desc "Restart Cable service via systemd"
  task :restart do
    on roles(fetch(:cable_role)) do
      git_plugin.execute_systemd("restart", fetch(:cable_service_unit_name))
    end
  end

  desc "Restart Cable socket via systemd"
  task :restart_socket do
    on roles(fetch(:cable_role)) do
      git_plugin.execute_systemd("restart", fetch(:cable_socket_unit_name))
    end
  end

  desc "Reload Cable service via systemd"
  task :reload do
    on roles(fetch(:cable_role)) do
      service_ok = if fetch(:cable_systemctl_user) == :system
        execute("#{fetch(:cable_systemctl_bin)} status #{fetch(:cable_service_unit_name)} > /dev/null", raise_on_non_zero_exit: false)
      else
        execute("#{fetch(:cable_systemctl_bin)} --user status #{fetch(:cable_service_unit_name)} > /dev/null", raise_on_non_zero_exit: false)
      end
      cmd = "reload"
      unless service_ok
        cmd = "restart"
      end
      if fetch(:cable_systemctl_user) == :system
        sudo "#{fetch(:cable_systemctl_bin)} #{cmd} #{fetch(:cable_service_unit_name)}"
      else
        execute fetch(:cable_systemctl_bin).to_s, "--user", cmd, fetch(:cable_service_unit_name)
      end
    end
  end

  desc "Get Cable service status via systemd"
  task :status do
    on roles(fetch(:cable_role)) do
      git_plugin.execute_systemd("status", fetch(:cable_service_unit_name))
      git_plugin.execute_systemd("status", fetch(:cable_socket_unit_name)) if fetch(:cable_enable_socket_service)
    end
  end
end
