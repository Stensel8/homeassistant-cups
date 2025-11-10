
CUPS Print Server (Home Assistant add-on)

What this does
- Runs CUPS (IPP) on port 631 (HTTPS)

Install (Supervisor)
- Add repository URL in Supervisor -> Add-on Store
- Install the add-on and start it

Build and run locally (optional)

```powershell
docker build -t homeassistant-cups:local .
docker run --rm -d -p 631:631 --name cups-local homeassistant-cups:local
```

Quick check
- CUPS (local): https://localhost:631/ (self-signed cert)

Configuration
- Configure via Supervisor add-on options.

Minimal. No extras.

