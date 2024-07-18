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
set :cable_port, 29292
# set :cable_limit_nofile, 65536 # optional, to customize if `Errno::EMFILE: Too many open files` happens
# set :cable_ssl_certificate
# set :cable_ssl_certificate_key
set :cable_rackup_file, 'cable/config.ru'
set :cable_dir, -> { File.join(release_path, "cable") }
set :cable_pidfile, -> { File.join(shared_path, "tmp", "pids", "cable.pid") }
set :cable_env, -> { fetch(:rack_env, fetch(:rails_env, fetch(:stage))) }
set :cable_access_log, -> { File.join(shared_path, "log", "cable.access.log") }
set :cable_error_log, -> { File.join(shared_path, "log", "cable.error.log") }
set :cable_phased_restart, -> { true }
set :cable_service_unit_env_files, -> { fetch(:service_unit_env_files, []) }
set :cable_service_unit_env_vars, -> { fetch(:service_unit_env_vars, []) }
set :cable_service_templates_path, fetch(:service_templates_path, "config/deploy/templates")
```
See Capistrao::Cable::Systemd#set_defaults for more details.

To enable SSL, set the `cable_ssl_certificate` and `cable_ssl_certificate_key` options.
The both are required to enable SSL.

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
