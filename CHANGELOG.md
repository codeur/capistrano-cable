## [Unreleased]

## [0.2.0] - 2026-09-15

- Replace `cable_port`, `cable_ssl_certificate` and `cable_ssl_certificate_key` with a single `cable_bind` option, defaulting to a unix socket in the shared directory
- Enable systemd socket activation by default, so the listening socket survives a restart of the server
- Install the systemd units at every deploy, before restarting the server

## [0.1.0] - 2024-07-05

- Initial release
