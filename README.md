
# CUPS Print Server for Home Assistant

Advanced CUPS print server add-on with full Home Assistant integration.

## Features
- 🖨️ CUPS 2.4.12 print server with AirPrint support
- 🏠 **Full Home Assistant Integration**
  - Native service calls (`cups.start_service`, `cups.restart_service`, etc.)
  - Real-time sensors (service status, print jobs)
  - Control switches in your dashboard
  - Ingress web interface embedded in Home Assistant
- 🔒 HTTPS/SSL encryption
- ⚙️ Configurable via Home Assistant UI
- 💾 Persistent configuration
- 🔌 USB printer support
- 📊 System monitoring and logging

## Configuration

```yaml
cups_username: "myuser"     # Change this!
cups_password: "mypass"     # Change this!
server_name: "My Printer" 
max_jobs: 100
ssl_enabled: true
```

## Home Assistant Integration

This add-on provides deep integration with Home Assistant:

### 🎛️ Dashboard Control
- Service status sensor: `binary_sensor.cups_service_status`
- Print jobs counter: `sensor.cups_print_jobs` 
- Service control switch: `switch.cups_service_control`
- Embedded web interface via **Ingress**

### 🔧 Service Calls
Use these services in your automations and scripts:
```yaml
# Restart CUPS service
service: cups.restart_service

# Start/stop service
service: cups.start_service
service: cups.stop_service

# Update configuration
service: cups.update_config
data:
  username: "admin"
  password: "newpassword" 
  port: 631
```

### 🤖 Example Automation
```yaml
automation:
  - alias: "Auto Restart CUPS"
    trigger:
      platform: state
      entity_id: binary_sensor.cups_service_status
      to: 'off'
      for: '00:02:00'
    action:
      - service: cups.restart_service
```

See `HOMEASSISTANT-INTEGRATION.md` for complete examples.

## Running Scripts

Choose your preferred startup script:
- Linux/macOS: Use `/run.sh` 
- Windows: Use `/run.ps1`

Both scripts do exactly the same thing.

## Troubleshooting

- Check add-on logs for errors
- Ensure USB devices are passed through
- Use debug mode if needed: set `cups_username` to `debug`
- Default credentials: `print`/`print` (change these!)

## Version 1.2.0

- Streamlined architecture
- Removed duplicate files and configurations  
- Improved startup process
- Better error handling
- Cleaned up unused services
