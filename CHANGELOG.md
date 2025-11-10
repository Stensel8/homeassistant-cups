# Changelog

All notable changes to this project are documented here.

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
