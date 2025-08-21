
# CUPS Print Server Add-on for Home Assistant

A simple, secure CUPS 2.4.12 print server with Home Assistant integration and an embedded web interface (Ingress).

## Features
- CUPS print server with AirPrint support
- Home Assistant services, sensors, and a control switch
- HTTPS/SSL support
- USB printer support
- Persistent configuration

## Quick start
1. Add this repository to Home Assistant Add-ons.
2. Install “CUPS Print Server”.
3. Open the add-on, set your username and password, and save.
4. Start the add-on and open the web interface via Ingress.

## Configuration (Add-on options)
Example:
```yaml
cups_username: "myuser"     # Change this
cups_password: "mypass"     # Change this
server_name: "My Printer"
cups_port: 631
management_port: 8080
max_jobs: 100
ssl_enabled: true
log_level: "info"
auto_discovery: true
allow_remote_admin: true
```

## Home Assistant integration
- Sensor: `binary_sensor.cups_service_status` (service up/down)
- Sensor: `sensor.cups_print_jobs` (active jobs)
- Switch: `switch.cups_service_control` (start/stop)

Services you can call in automations:
- `cups.start_service`
- `cups.stop_service`
- `cups.restart_service`
- `cups.get_status`
- `cups.update_config`

Example automation:
```yaml
automation:
  - alias: "Auto restart CUPS when offline"
    trigger:
      platform: state
      entity_id: binary_sensor.cups_service_status
      to: 'off'
      for: '00:02:00'
    action:
      - service: cups.restart_service
```

## Troubleshooting
- Check the add-on logs for errors.
- Ensure USB devices are passed through to the host.
- Use `log_level: debug` for more details.
- Default credentials are `print/print` (change them).

## Version
Current version: 1.2.1
