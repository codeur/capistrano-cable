# Capistrano::Cable

**Capistrano::Cable** helps to deploy standalone ActionCable server with Puma over `systemd`.
It doesn't use a specific `puma.rb` for Puma configuration, it relies on given options.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add capistrano-cable

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install capistrano-cable

## Usage

```ruby
# Capfile

require 'capistrano/cable'
install_plugin Capistrano::Cable::Systemd
```

To prevent loading the hooks of the plugin, add false to the load_hooks param.
```ruby
# Capfile

install_plugin Capistrano::Cable, load_hooks: false  # Default cable tasks without hooks
```

To make it work with rvm, rbenv and chruby, install the plugin after corresponding library inclusion.
```ruby
# Capfile

require 'capistrano/rbenv'
require 'capistrano/cable'
install_plugin Capistrano::Cable
```

### Config
Many options are available to customize the cable server configuration. Here are the main ones:

```ruby
# config/deploy.rb or config/deploy/<stage>.rb
set :cable_role, :web
set :cable_bind, -> { "unix://#{shared_path.join("tmp", "sockets", "cable.sock")}" }
# set :cable_limit_nofile, 65536 # optional, to customize if `Errno::EMFILE: Too many open files` happens
set :cable_rackup_file, 'cable/config.ru'
set :cable_dir, -> { File.join(release_path, "cable") }
set :cable_pidfile, -> { File.join(shared_path, "tmp", "pids", "cable.pid") }
set :cable_env, -> { fetch(:rack_env, fetch(:rails_env, fetch(:stage))) }
set :cable_access_log, -> { File.join(shared_path, "log", "cable.access.log") }
set :cable_error_log, -> { File.join(shared_path, "log", "cable.error.log") }
set :cable_phased_restart, -> { true }
set :cable_enable_socket_service, true
set :cable_service_unit_env_files, -> { fetch(:service_unit_env_files, []) }
set :cable_service_unit_env_vars, -> { fetch(:service_unit_env_vars, []) }
set :cable_service_templates_path, fetch(:service_templates_path, "config/deploy/templates")
```
See Capistrao::Cable::Systemd#set_defaults for more details.

### Where the server listens

`cable_bind` is the only option about listening. It takes a Puma bind string, or
an array of them:

```ruby
set :cable_bind, "unix:///home/myapp/public_html/shared/tmp/sockets/cable.sock"
set :cable_bind, "tcp://0.0.0.0:28090"
set :cable_bind, "ssl://0.0.0.0:28090?cert=/path/cert.pem&key=/path/key.pem"
```

By default the server listens on a unix socket in the shared directory, which
keeps it unreachable from the outside and saves picking a free port on every
host. The socket directory is created by `cable:install`; the web server in
front then proxies to that socket path instead of a host and port, the way it
proxies to any other unix socket.

A unix socket path has to be absolute: write `unix:///path/to/cable.sock`, with
three slashes.

### Socket activation

With `cable_enable_socket_service` (enabled by default), systemd owns the
listening socket and hands it over to Puma. The socket stays open while the
service restarts, so connections are queued in the backlog instead of being
refused, and the server is started on the first request if it is not running
yet.

The `ListenStream` of the socket unit is the address of each `cable_bind`: Puma
matches the socket it receives against its own binds, so both are always
written from the same option.

## Migrating to 0.2.0

`cable_port`, `cable_ssl_certificate` and `cable_ssl_certificate_key` are gone,
replaced by `cable_bind`. A deploy that still sets one of them stops right away
with a message telling what to write instead.

Nothing else to do on the Capistrano side: the systemd units are now installed
at every deploy, before the server is restarted, so upgrading the gem and
deploying is enough to move an app to its socket.

The one manual step is the web server, which has to proxy to the socket instead
of the port. If both can't be changed in the same window, keep the port for
now:

```ruby
set :cable_bind, "tcp://0.0.0.0:28090"
```

and move to the default socket in a later deploy.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/codeur/capistrano-cable. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/codeur/capistrano-cable/blob/main/CODE_OF_CONDUCT.md).

Largely inspired from [capistrano-puma](https://github.com/seuros/capistrano-puma) gem.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Capistrano::Cable project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/codeur/capistrano-cable/blob/main/CODE_OF_CONDUCT.md).
