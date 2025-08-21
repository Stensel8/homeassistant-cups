#!/usr/bin/env pwsh
# Quick CUPS Container Test
# Simple script to test if the container is working

$ErrorActionPreference = "SilentlyContinue"

Write-Host "🔍 Quick CUPS Container Test" -ForegroundColor Green
Write-Host "=" * 30

$containerName = "homeassistant-cups"

# Test 1: Is container running?
$running = docker ps -q --filter "name=$containerName"
if ($running) {
    Write-Host "✅ Container is running" -ForegroundColor Green
} else {
    Write-Host "❌ Container is not running" -ForegroundColor Red
    Write-Host "Try: ./run.ps1 run" -ForegroundColor Yellow
    exit 1
}

# Test 2: Can we access management interface?
try {
    $mgmt = Invoke-WebRequest -Uri "http://localhost:8080/api/status" -TimeoutSec 5 -UseBasicParsing
    Write-Host "✅ Management interface works: http://localhost:8080" -ForegroundColor Green
} catch {
    Write-Host "❌ Management interface failed" -ForegroundColor Red
}

# Test 3: Can we access CUPS HTTP?
try {
    $cupsHttp = Invoke-WebRequest -Uri "http://localhost:8631" -TimeoutSec 5 -UseBasicParsing
    Write-Host "✅ CUPS HTTP works: http://localhost:8631" -ForegroundColor Green
} catch {
    Write-Host "❌ CUPS HTTP failed" -ForegroundColor Red
}

# Test 4: Can we access CUPS HTTPS?
try {
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $cupsHttps = Invoke-WebRequest -Uri "https://localhost:631" -TimeoutSec 5 -UseBasicParsing
    Write-Host "✅ CUPS HTTPS works: https://localhost:631" -ForegroundColor Green
} catch {
    Write-Host "❌ CUPS HTTPS failed" -ForegroundColor Red
}

Write-Host "`n🔧 If any tests failed, try:" -ForegroundColor Yellow
Write-Host "   ./run.ps1 restart" -ForegroundColor White
Write-Host "   ./validate-cups.ps1  (full diagnostics)" -ForegroundColor White
Write-Host "   ./run.ps1 logs  (view logs)" -ForegroundColor White

Write-Host "`n📖 Default login: print / print" -ForegroundColor Cyan