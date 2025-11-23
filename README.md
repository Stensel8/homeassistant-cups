# CUPS Print Server – Home Assistant Add-on

[![Open your Home Assistant instance and show the add add-on repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fstensel8%2Fhomeassistant-cups)

Run a CUPS 2.4.14 print server in Home Assistant with full web UI and AirPrint support.

- HTTPS CUPS web interface (port 631)
- Add/manage printers via CUPS admin UI
- AirPrint & mDNS discovery for Apple devices
- Self-signed TLS certificate included

## Installation

1. Add this repo in Supervisor → Add-on store
2. Install **CUPS Print Server**
3. Set admin username & password in config
4. Start the add-on
5. Access CUPS at `https://[HOST]:631`

## Configuration

| Option         | Example    | Purpose             |
|----------------|------------|---------------------|
| admin_username | admin      | CUPS admin user     |
| admin_password | strongpass | CUPS admin password |
| ssl_enabled    | true       | Enable HTTPS        |
| log_level      | info       | Log verbosity       |

## AirPrint

Enable AirPrint for automatic printer discovery on Apple devices. Avahi handles mDNS/Bonjour inside the container.

## Building Multi-Arch Images

**PowerShell:**
```pwsh
./scripts/buildx-build.ps1 -Push
```

**GitHub Actions:**

The workflow automatically builds and pushes images on tag push (e.g., `v2.0.0`) or manual trigger.

Required secret: `DOCKERHUB_TOKEN` (Docker Hub Personal Access Token)
- Go to Settings → Secrets and variables → Actions → New repository secret
- Name: `DOCKERHUB_TOKEN`
- Value: Your Docker Hub token

## Version Management

The version is stored in the top-level [`VERSION`](./VERSION) file. 

---