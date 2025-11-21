# Changelog

All notable changes to this project are documented here.

## 1.3.5 - 2025-11-21
### Added/Improved
- Improved mDNS/Avahi discovery support; installed `libnss-mdns` and `avahi-utils` to enable `.local` resolution and discovery parsing.
- Discovery-only mode: the add-on will now detect `_ipp._tcp` services and write metadata to `/var/cache/cups/discovered` but **will not** auto-add printers to CUPS by default.
- Discovery-only mode: the add-on will now detect `_ipp._tcp` services and write metadata to `/var/cache/cups/discovered` but **will not** auto-add printers to CUPS by default.
- Added a minimal Discovery UI (read-only) available at `http://[HOST]:8080/` that shows discovered printers and links to the CUPS Admin UI.
- Clarified that the add-on no longer overwrites `ServerName` in `cupsd.conf`: keep configuration minimal and read from persisted config in `/config/cups` when available.
- Discovery is read-only and the add-on does not auto-add printers. Administrators can review discovered metadata and add printers using the CUPS web UI.
- Added a monitor service to automatically restart `cupsd` if it crashes unexpectedly.
- Improved health checks and runtime warnings for optional discovery tools (avahi-browse, avahi-resolve).

### Fixed
- Fixed Avahi configuration that previously bound to a specific interface (eth0); `allow-interfaces` removed so discovery works across environments.
- Various startup and configuration fixes to improve reliability and debugging (CUPS debug mode, better ServerName detection).

## 1.3.1 - 2025-11-11
### Fixed
- Home Assistant add-on panel now correctly displays the dynamic URL and "Open Web UI" button for managing the CUPS instance
- Resolved ERR_CONNECTION_REFUSED errors in Home Assistant by fixing config key mismatches and enabling direct host port access
- Corrected bashio config loading to use proper keys (cupsusername, cupspassword) from add-on options

## 1.3.0 - 2025-11-10
### Added
- Synced support metadata and configuration; requires Home Assistant Core & Supervisor 2025.11.1
- Bumped to CUPS 2.4.14
- Deprecated config.json and consolidated settings into config.yaml
- Notes for Operating System 16.3 and Frontend 20251105.0
- English documentation and improved logging
- Secure HTTPS-only CUPS
- Configurable admin credentials via the Home Assistant add-on config panel
- Status and uptime statistics in the add-on GUI

### Changed
- Bumped project version to 1.3.0 and synchronized configuration files
- Consolidated release metadata and settings for simpler maintenance


## 1.2.1 - 2025-08-21
### Changed
- Documentation simplified and translated to English
- Consolidated to a single README and CHANGELOG
- Removed emojis and redundant text

### Fixed
- Minor wording and clarity improvements

## 1.2.0 - 2025-08-20
### Added
- Health check monitoring
- Dynamic CUPS configuration generation
- PowerShell startup script (run.ps1)

### Changed
- Simplified architecture
- Improved startup and error handling

### Fixed
- Hardcoded credentials
- Service startup stability

## 1.1.0 - 2025-08-18
### Added
- Home Assistant services integration improvements
- Logging and configuration improvements

### Changed
- Cleanup of unused code

## 1.0.0 - 2025-08-15
### Added
- Initial release
- CUPS 2.4.2 with IPP support
- HTTPS support
- Home Assistant add-on integration
