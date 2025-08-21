#!/usr/bin/env pwsh
# CUPS Container Validation Script
# Tests connectivity and diagnoses issues

param(
    [string]$ContainerName = "homeassistant-cups"
)

$ErrorActionPreference = "Continue"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message) 
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

Write-Info "🔍 CUPS Container Validation Starting..."
Write-Info "Container: $ContainerName"
Write-Info "=" * 50

# Test 1: Container Status
Write-Info "1. Checking container status..."
$containerRunning = docker ps -q --filter "name=$ContainerName"
if ($containerRunning) {
    Write-Success "Container is running (ID: $containerRunning)"
} else {
    Write-Error "Container is not running!"
    Write-Info "Try: ./run.ps1 run"
    exit 1
}

# Test 2: Container Health
Write-Info "`n2. Checking container health..."
$healthStatus = docker inspect $ContainerName --format='{{.State.Health.Status}}'
if ($healthStatus -eq "healthy") {
    Write-Success "Container is healthy"
} elseif ($healthStatus -eq "starting") {
    Write-Warning "Container is still starting up - wait a moment and try again"
    Write-Info "This script will continue but services might not be ready yet"
} else {
    Write-Error "Container health: $healthStatus"
    Write-Info "Check logs: ./run.ps1 logs"
}

# Test 3: Process Check
Write-Info "`n3. Checking internal processes..."
try {
    $processes = docker exec $ContainerName ps aux | Select-String "cupsd|supervisord|python"
    if ($processes) {
        Write-Success "Key processes are running:"
        $processes | ForEach-Object { Write-Host "  - $($_.Line)" -ForegroundColor Cyan }
    } else {
        Write-Error "Key processes not found"
    }
} catch {
    Write-Error "Could not check processes: $_"
}

# Test 4: SSL Certificates
Write-Info "`n4. Checking SSL certificates..."
try {
    $sslFiles = docker exec $ContainerName ls -la /etc/cups/ssl/
    if ($sslFiles -match "server.crt" -and $sslFiles -match "server.key") {
        Write-Success "SSL certificates exist"
    } else {
        Write-Error "SSL certificates missing"
        Write-Info "Try restarting container to regenerate certificates"
    }
} catch {
    Write-Warning "Could not check SSL certificates: $_"
}

# Test 5: Management API (Port 8080)
Write-Info "`n5. Testing Management API (port 8080)..."
try {
    $mgmtResponse = Invoke-WebRequest -Uri "http://localhost:8080/api/status" -TimeoutSec 10 -UseBasicParsing
    if ($mgmtResponse.StatusCode -eq 200) {
        Write-Success "Management API is responding"
        Write-Info "Try: http://localhost:8080"
    } else {
        Write-Warning "Management API returned status: $($mgmtResponse.StatusCode)"
    }
} catch {
    Write-Error "Management API not accessible: $($_.Exception.Message)"
    Write-Info "Check if port 8080 is blocked by firewall"
}

# Test 6: CUPS HTTPS (Port 631)
Write-Info "`n6. Testing CUPS HTTPS (port 631)..."
try {
    # Skip certificate validation for self-signed cert
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $cupsResponse = Invoke-WebRequest -Uri "https://localhost:631" -TimeoutSec 10 -UseBasicParsing
    if ($cupsResponse.StatusCode -eq 200) {
        Write-Success "CUPS HTTPS interface is responding"
        Write-Info "Try: https://localhost:631"
    } else {
        Write-Warning "CUPS returned status: $($cupsResponse.StatusCode)"
    }
} catch {
    Write-Error "CUPS HTTPS not accessible: $($_.Exception.Message)"
    Write-Info "Check if port 631 is blocked by firewall"
}

# Test 7: CUPS HTTP Fallback (Port 8631)
Write-Info "`n7. Testing CUPS HTTP fallback (port 8631)..."
try {
    $cupsHttpResponse = Invoke-WebRequest -Uri "http://localhost:8631" -TimeoutSec 10 -UseBasicParsing
    if ($cupsHttpResponse.StatusCode -eq 200) {
        Write-Success "CUPS HTTP interface is responding"
        Write-Info "Try: http://localhost:8631"
    } else {
        Write-Warning "CUPS HTTP returned status: $($cupsHttpResponse.StatusCode)"
    }
} catch {
    Write-Error "CUPS HTTP not accessible: $($_.Exception.Message)"
    Write-Info "This is the fallback interface for troubleshooting"
}

# Test 7: Container Logs Check
Write-Info "`n8. Checking recent container logs for errors..."
try {
    $recentLogs = docker logs --tail 20 $ContainerName 2>&1
    $errors = $recentLogs | Select-String -Pattern "ERROR|FATAL|Failed"
    if ($errors) {
        Write-Warning "Recent errors found in logs:"
        $errors | ForEach-Object { Write-Host "  - $($_.Line)" -ForegroundColor Red }
    } else {
        Write-Success "No recent errors in logs"
    }
} catch {
    Write-Warning "Could not check logs: $_"
}

# Final Recommendations
Write-Info "`n" + "=" * 50
Write-Info "🎯 FINAL ASSESSMENT & RECOMMENDATIONS"
Write-Info "=" * 50

# Determine overall status
$overallSuccess = $true
if (-not $containerRunning) { $overallSuccess = $false }
if ($healthStatus -ne "healthy" -and $healthStatus -ne "starting") { $overallSuccess = $false }

if ($overallSuccess) {
    Write-Success "`n✅ Container appears to be working correctly!"
    Write-Info "`nAccess your services:"
    Write-Host "  • Management Interface: " -NoNewline; Write-Host "http://localhost:8080" -ForegroundColor Cyan
    Write-Host "  • CUPS Interface (HTTPS): " -NoNewline; Write-Host "https://localhost:631" -ForegroundColor Cyan
    Write-Host "  • CUPS Interface (HTTP): " -NoNewline; Write-Host "http://localhost:8631" -ForegroundColor Cyan
    Write-Host "  • Default credentials: " -NoNewline; Write-Host "print / print" -ForegroundColor Yellow
} else {
    Write-Error "`n❌ Issues detected with container setup"
    Write-Info "`nTroubleshooting steps:"
    Write-Host "  1. Restart container: " -NoNewline; Write-Host "./run.ps1 restart" -ForegroundColor Yellow
    Write-Host "  2. Check logs: " -NoNewline; Write-Host "./run.ps1 logs" -ForegroundColor Yellow  
    Write-Host "  3. Rebuild if needed: " -NoNewline; Write-Host "./run.ps1 clean && ./run.ps1 run" -ForegroundColor Yellow
    Write-Host "  4. Check TROUBLESHOOTING.md for more help"
}

Write-Info "`nValidation completed! 🏁"