# CUPS Print Server - Home Assistant Add-on

[![Open your Home Assistant instance and show the add add-on repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2FStensel8%2Fhomeassistant-cups)

This add-on runs a secure CUPS (Unix Printing System) server on port 631 (HTTPS only) with full admin support.

## Features
- Secure CUPS server accessible via HTTPS
- Home Assistant configuration for admin username/password
- Web interface with admin privileges
- AirPrint support
- Automatic status and stats logging for monitoring within the add-on tab

## Installation
1. Add the repository URL in Supervisor -> Add-on Store
2. Install and start the add-on

## Configuration
Change the admin username and password via the Home Assistant add-on GUI options.

## Access
- CUPS Web Interface: https://localhost:631/
- Username and password: Set in the add-on options

## Status Panel
Live stats and uptime are available in the add-on tab.

## Troubleshooting
- Ensure port 631 is available and not blocked by firewalls
- Accept the self-signed SSL certificate for first-time access
- For "Forbidden" errors, make sure your username is in the lpadmin group in start-services.sh
