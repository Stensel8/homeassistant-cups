# CUPS Print Server - Home Assistant Add-on

[![Open your Home Assistant instance and show the add add-on repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2FStensel8%2Fhomeassistant-cups)

This add-on runs a secure CUPS (Unix Printing System) server on port 631 (HTTPS only) with full admin support.

## Features
- Secure CUPS server accessible via HTTPS
- Home Assistant configuration for admin username/password
- Web interface with admin privileges
- AirPrint support
- Automatic status and stats logging for monitoring within the add-on tab

## Discovery & mDNS improvements

This add-on now includes improved mDNS/Avahi support and automatic IPP printer discovery:

- Installs `libnss-mdns` and updates `/etc/nsswitch.conf` for `.local` hostname resolution.
- Installs `avahi-utils` and uses `avahi-browse` to find `_ipp._tcp` printers on the network.
- NOTE: The discovery script only discovers printers and writes metadata so you can manually
	add printers using the CUPS web UI. It does NOT auto-add printers to CUPS anymore.
Generates a default self-signed TLS certificate with CN=localhost and SAN entries for `localhost` and `127.0.0.1`. If you want to use custom certificates or include a different SAN (container IP), provide your own certificates via the add-on `ssl` folder in `addon-config` or set `CERT_HOST_IP` via the advanced options.

If your HP Envy 6420e doesn't appear during discovery, check if the printer is configured with HP+ and whether local printing is disabled by HP. Policy changes by HP can disable discovery and local printing.

> ⚠️ Note: For the most reliable mDNS and Avahi discovery, run the add-on with `host_network: true` in the add-on `config.yaml`. Container bridge networking (default) may prevent Avahi from seeing devices on the LAN and can break discovery.

### Debugging & Diagnostics

To debug discovery and connectivity problems, run the add-on with the following options or use the container shell:

1. Enable CUPS debug logging by setting the addon option `cupsdebug` in the add-on settings (or by setting environment variable `CUPS_DEBUG=true`). This sets `LogLevel debug` in `cupsd.conf`.
2. Check that Avahi is running and can resolve mDNS:

```bash
avahi-browse --parsable -r -t _ipp._tcp
avahi-resolve -n some-printer.local
```

3. Check that the printer is visible in CUPS and that the driverless IPP URI is present:

```bash
lpstat -v
lpinfo -v
```

4. If you see TLS name mismatch issues, ensure you access the CUPS web UI by one of the names contained in the certificate (e.g., `localhost` or the container IP). The add-on generates a default self-signed certificate; if you want to control the SANs, provide your own certificates or configure `CERT_HOST_IP` in an environment/advanced option.

### Discovery Data

The discovery service (not a printer auto-add script) writes discovered printer metadata to:

```
/var/cache/cups/discovered
```

Each discovered printer will be written into a separate `*.txt` file with key=value lines, for example:

```
name=HP Envy 6420e
pname=HP_Envy_6420e
host=printer.local
address=192.168.1.100
port=631
resource=/ipp/print
service=_ipp._tcp
domain=local
```

You can use this data to either manually add printers via the CUPS Web UI (`https://[HOST]:631`) or for custom integration with Home Assistant.

Discovery is read-only by default; the add-on detects printers and writes their metadata to `/var/cache/cups/discovered`. Add printers manually in the CUPS admin UI as described above.

To manually add a discovered printer in the CUPS web UI:
1. Open the CUPS admin page: https://[HOST]:631
2. Go to "Administration" -> "Add Printer" (you may be asked for the `lpadmin` credentials configured in this add-on)
3. Choose 'Internet Printing Protocol (IPP)' or 'AppSocket/HP JetDirect' depending on what the device advertises, and use the discovered URI (e.g., `ipp://192.168.1.100:631/ipp/print`).
4. Complete any required driver or name details in the UI.


## Installation
1. Add the repository URL in Supervisor -> Add-on Store
2. Install and start the add-on

## Configuration
Change the admin username and password via the Home Assistant add-on GUI options.

## Access
- CUPS Web Interface: https://[HOST]:631/ (replace [HOST] with your host IP or hostname; Supervisor will show the correct URL in the add-on panel)
 - CUPS Web Interface: https://[HOST]:631/ (replace [HOST] with your host IP or hostname; Supervisor will show the correct URL in the add-on panel)
 - Discovered Printers UI (read-only): http://[HOST]:8080/
- Username and password: Set in the add-on options

## Status Panel
Live stats and uptime are available in the add-on tab.

## Troubleshooting
- Ensure port 631 is available and not blocked by firewalls
- Accept the self-signed SSL certificate for first-time access
- For "Forbidden" errors, make sure your username is in the lpadmin group in start-services.sh
