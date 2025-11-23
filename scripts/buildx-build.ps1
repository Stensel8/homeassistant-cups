param(
  [string]$Image = 'stensel8/homeassistant-cups',
  [string]$Tag = '',
  [string]$Platforms = 'linux/amd64,linux/arm64',
  [switch]$Push
)

$ErrorActionPreference = 'Stop'

# Determine tag: passed arg > VERSION file > default
if (-not $Tag) {
    $versionFile = Join-Path $PSScriptRoot '..\VERSION'
    if (Test-Path $versionFile) {
        $Tag = (Get-Content -Raw $versionFile).Trim()
    } else {
        $Tag = '2.0.0'
    }
}

# Ensure we don't include a leading 'v' in the tag (drop it entirely)
$Tag = $Tag -replace '^v',''

$fullTag = "$($Image):$($Tag)"

Write-Host "Building multi-arch image: $fullTag" -ForegroundColor Cyan
Write-Host "Platforms: $Platforms" -ForegroundColor Cyan
Write-Host ""

$cmd = "docker buildx build --platform $Platforms -t $fullTag ./"
if ($Push) { 
    $cmd += ' --push'
    Write-Host "Build mode: push enabled" -ForegroundColor Yellow
} else {
    Write-Host "Build mode: local only (no push)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Executing: $cmd" -ForegroundColor Gray
Invoke-Expression $cmd

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Build completed successfully!" -ForegroundColor Green
    if (-not $Push) {
        Write-Host ""
        Write-Host "To push this image to Docker Hub:" -ForegroundColor Yellow
        Write-Host "  1. Log in: docker login -u stensel8" -ForegroundColor White
        Write-Host "  2. Push: docker buildx build --platform $Platforms -t $fullTag --push ./" -ForegroundColor White
        Write-Host ""
        Write-Host "Or re-run this script with -Push flag" -ForegroundColor Yellow
    }
} else {
    Write-Host ""
    Write-Host "Build failed with exit code $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}