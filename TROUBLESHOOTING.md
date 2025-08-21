# 🔧 CUPS Container Troubleshooting Guide

## Quick Fix for Connection Issues

If you're getting `ERR_CONNECTION_CLOSED` or `ERR_EMPTY_RESPONSE` errors, follow these steps:

### Step 1: Rebuild and Restart Container

```powershell
# Stop current container
./run.ps1 stop

# Rebuild with fixes
./run.ps1 build

# Start fresh container
./run.ps1 run
```

### Step 2: Wait for Full Startup

The container needs time to:
- Generate SSL certificates
- Start CUPS daemon
- Initialize management API
- Complete health checks

**Wait at least 2-3 minutes** after seeing "Container started successfully" before accessing interfaces.

### Step 3: Check Container Logs

```powershell
# View real-time logs
./run.ps1 logs
```

Look for these success indicators:
- `SSL certificates generated successfully!`
- `CUPS is responding on HTTPS port`
- `Management API starting on port 8080`
- `All services healthy`

### Step 4: Test Connectivity

Try accessing the interfaces in this order:

1. **Management Interface**: http://localhost:8080
   - Should load immediately if working
   - Has troubleshooting tools built-in

2. **CUPS Interface (HTTP)**: http://localhost:8631
   - HTTP fallback interface for troubleshooting
   - Use credentials: `print` / `print` (default)

3. **CUPS Interface (HTTPS)**: https://localhost:631
   - May show SSL warning (click "Advanced" → "Proceed")
   - Use credentials: `print` / `print` (default)

### Step 5: Advanced Troubleshooting

#### Check if services are running inside container:
```powershell
docker exec homeassistant-cups ps aux | findstr "cupsd\|python"
```

#### Test management API from inside container:
```powershell
docker exec homeassistant-cups curl -s http://localhost:8080/api/status
```

#### Test CUPS HTTP interface from inside container:
```powershell  
docker exec homeassistant-cups curl -s http://localhost:8631
```

#### Test CUPS HTTPS interface from inside container:
```powershell
docker exec homeassistant-cups curl -k -s https://localhost:631
```

#### Check SSL certificates:
```powershell
docker exec homeassistant-cups ls -la /etc/cups/ssl/
```

### Common Issues & Solutions

| Issue | Symptoms | Solution |
|-------|----------|----------|
| **SSL Certificate Problems** | CUPS interface not loading | Restart container, certificates will regenerate |
| **Management API Down** | Port 8080 not responding | Check logs for Python errors, restart container |
| **CUPS Not Starting** | Both interfaces down | Check logs for CUPS daemon errors |
| **Race Condition** | Intermittent failures | Wait longer between startup and access |

### Configuration Changes Applied

The following fixes have been applied to resolve connection issues:

1. **SSL Configuration**: Made encryption requirements less strict during startup
2. **Certificate Generation**: Automatic SSL certificate creation with proper permissions  
3. **Health Checks**: Improved connectivity testing before marking container as healthy
4. **Startup Timing**: Added proper wait times for service initialization
5. **Error Handling**: Fixed logging errors in management API

### If Problems Persist

1. **Check Windows Firewall**: Ensure ports 631 and 8080 are allowed
2. **Try Different Browser**: Chrome may have strict SSL requirements
3. **Use HTTP for Testing**: Try http://localhost:631 (may redirect to HTTPS)
4. **Container Resources**: Ensure Docker has adequate memory/CPU allocated

### Success Indicators

✅ **Working Setup Shows**:
- Management interface loads at http://localhost:8080
- CUPS HTTP interface loads at http://localhost:8631 (fallback)
- CUPS HTTPS interface loads at https://localhost:631 (with SSL warning)
- Container logs show "All services healthy"
- Both services respond to connectivity tests

Need help? The management interface at http://localhost:8080 has built-in diagnostic tools and system information.