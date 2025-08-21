# Home Assistant Integration Examples for CUPS Add-on
# Add these to your Home Assistant configuration

# 1. Automation: Restart CUPS when offline
automation:
  - id: cups_auto_restart
    alias: "Auto Restart CUPS Print Server"
    description: "Automatically restart CUPS if it goes offline"
    trigger:
      - platform: state
        entity_id: binary_sensor.cups_service_status
        to: 'off'
        for:
          minutes: 2
    action:
      - service: cups.restart_service
      - service: notify.persistent_notification
        data:
          title: "CUPS Print Server"
          message: "CUPS service was offline and has been restarted automatically."

# 2. Sensor: CUPS Statistics
sensor:
  - platform: rest
    name: "CUPS Server Info"
    resource: "http://localhost:8080/api/system-info"
    scan_interval: 300
    value_template: "{{ value_json.status | default('unknown') }}"
    json_attributes:
      - uptime
      - memory_usage
      - disk_usage

# 3. Input fields for CUPS configuration
input_text:
  cups_username:
    name: "CUPS Username"
    initial: "print"
    min: 3
    max: 20
    
  cups_password:
    name: "CUPS Password"
    mode: password
    initial: "print"
    min: 4
    max: 50

input_number:
  cups_port:
    name: "CUPS Port"
    min: 1024
    max: 65535
    initial: 631
    step: 1

# 4. Script: Update CUPS Configuration
script:
  update_cups_config:
    alias: "Update CUPS Configuration"
    sequence:
      - service: cups.update_config
        data:
          username: "{{ states('input_text.cups_username') }}"
          password: "{{ states('input_text.cups_password') }}"
          port: "{{ states('input_number.cups_port') | int }}"
      - service: notify.persistent_notification
        data:
          title: "CUPS Configuration"
          message: "CUPS configuration has been updated. Restart the service to apply changes."

# 5. Lovelace Dashboard Card
lovelace:
  dashboards:
    cups-dashboard:
      mode: yaml
      title: CUPS Print Server
      filename: cups-dashboard.yaml
      
# cups-dashboard.yaml content:
views:
  - title: Print Server
    cards:
      - type: entities
        title: CUPS Print Server Control
        entities:
          - entity: binary_sensor.cups_service_status
            name: "Service Status"
          - entity: sensor.cups_print_jobs
            name: "Active Print Jobs"
          - entity: switch.cups_service_control
            name: "Service Control"
            
      - type: iframe
        url: "[INGRESS_URL]"
        title: "CUPS Management"
        aspect_ratio: "16:9"
        
      - type: button
        entity: script.update_cups_config
        name: "Update Config"
        icon: mdi:cog
        tap_action:
          action: call-service
          service: script.update_cups_config
          
      - type: entities
        title: Configuration
        entities:
          - input_text.cups_username
          - input_text.cups_password
          - input_number.cups_port

# 6. Service calls you can use in automations or scripts:

# Start CUPS service:
# service: cups.start_service

# Stop CUPS service:
# service: cups.stop_service

# Restart CUPS service:
# service: cups.restart_service

# Get CUPS status:
# service: cups.get_status

# Update CUPS configuration:
# service: cups.update_config
# data:
#   username: "admin"
#   password: "newpassword"
#   port: 631
