# CUPS Print Server – Home Assistant Add-on

[![Open your Home Assistant instance and show the add add-on repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2FStensel8%2Fhomeassistant-cups)

Run a real CUPS 2.4.14 print server right from Home Assistant, with full HTTPS web UI and AirPrint/Avahi support.

- Secure CUPS web interface (port 631)
- Add/manage printers via the built-in CUPS admin UI
- Easy setup of `admin` user/password via the Home Assistant addon config
- AirPrint & mDNS discovery for Apple devices (optional)
- Generates a self-signed TLS cert by default

## Installation

1. Add this repo URL in Supervisor > Add-on store.
2. Install **CUPS Print Server**.
3. Set your admin username & password in the add-on config.
4. Start the add-on.
5. Open the CUPS web interface at: `https://[HOST]:631`

## Configuration

Edit these options in Home Assistant GUI:

| Option            | Example    | Purpose              |
|-------------------|------------|----------------------|
| admin_username    | admin      | CUPS admin user      |
| admin_password    | strongpass | CUPS admin password  |
| ssl_enabled       | true       | Enable HTTPS         |
| log_level         | info       | Log verbosity        |

## AirPrint/Bonjour mDNS

Enable AirPrint so Apple and network devices can find your printers automatically! Avahi runs inside the container for mDNS/Bonjour support.

> ⚠️ To improve AirPrint/mDNS, use `host_network: true` in the add-on config (optional, only if needed).

## Updating and Settings

- Changes to printers/users/settings in the **CUPS web UI** are applied immediately.
- Add-on config changes require a restart.

## Important Notes

- The CUPS UI is always available on `https://[HOST]:631`
- Use your configured admin credentials for adding/removing printers.
- Accept the self-signed SSL certificate in your browser.

## Troubleshooting

- If you don't see printers with AirPrint, try enabling `host_network: true`.
- Check logs in Supervisor if CUPS won't start.
- Make sure admin user is in the `lpadmin` group – this is handled automatically by this add-on.

## About

- Add-on version: 2.0.0
- CUPS version: 2.4.14

---

**Ready to print!**
