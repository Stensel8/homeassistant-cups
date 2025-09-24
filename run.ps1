#!/usr/bin/env pwsh
param(
    [Parameter(HelpMessage="Action to perform")]
    [ValidateSet("build", "run", "stop", "restart", "logs", "clean", "help", "status", "config", "shell", "kill", "pause", "unpause")]
    [string]$Action = "run",
    
    [Parameter(HelpMessage="Container name")]
    [string]$ContainerName = "homeassistant-cups",
    
    [Parameter(HelpMessage="Image name")]
    [string]$ImageName = "cups-addon:ha-integration",
    
    [Parameter(HelpMessage="CUPS port mapping")]
    [int]$CupsPort = 631,
    
    [Parameter(HelpMessage="Management port mapping")]
    [int]$MgmtPort = 8080,
    
    [Parameter(HelpMessage="CUPS username")]
    [string]$Username = "print",
    
    [Parameter(HelpMessage="CUPS password")]
    [string]$Password = "print",
    
    [Parameter(HelpMessage="Use privileged mode")]
    [switch]$Privileged
)

$ErrorActionPreference = "Stop"

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

function Build-Image {
    Write-Info "Building Podman image: $ImageName"
    try {
        podman build -t $ImageName .
        Write-Info "Build completed successfully"
    }
    catch {
        Write-Error "Build failed: $_"
        exit 1
    }
}

function Stop-Container {
    param([bool]$Silent = $false)
    
    if (-not $Silent) {
        Write-Info "Stopping container: $ContainerName"
    }
    
    try {
        $running = podman ps -q --filter "name=$ContainerName" 2>$null
        if ($running) {
            podman stop $ContainerName | Out-Null
            if (-not $Silent) {
                Write-Info "Container stopped"
            }
            return $true
        }
        else {
            if (-not $Silent) {
                Write-Warning "Container $ContainerName is not running"
            }
            return $false
        }
    }
    catch {
        if (-not $Silent) {
            Write-Warning "Could not stop container: $_"
        }
        return $false
    }
}

function Remove-Container {
    param([bool]$Silent = $false)
    
    if (-not $Silent) {
        Write-Info "Removing container: $ContainerName"
    }
    
    try {
        $exists = podman ps -aq --filter "name=$ContainerName" 2>$null
        if ($exists) {
            podman rm $ContainerName | Out-Null
            if (-not $Silent) {
                Write-Info "Container removed"
            }
            return $true
        }
        else {
            if (-not $Silent) {
                Write-Warning "Container $ContainerName does not exist"
            }
            return $false
        }
    }
    catch {
        if (-not $Silent) {
            Write-Warning "Could not remove container: $_"
        }
        return $false
    }
}

function Start-Container {
    param([bool]$ForceRestart = $false)
    
    # Check if container is already running
    if (-not $ForceRestart) {
        $running = podman ps -q --filter "name=$ContainerName" 2>$null
        if ($running) {
            Write-Info "Container $ContainerName is already running"
            Write-Info "Container ID: $running"
            Write-Info "CUPS Web Interface: https://localhost:$CupsPort"
            Write-Info "Management Interface: http://localhost:$MgmtPort"
            Write-Info "Login with: $Username / $Password"
            return
        }
    }
    
    Write-Info "Starting container: $ContainerName"
    Write-Info "CUPS Port: ${CupsPort}:631"
    Write-Info "Management Port: ${MgmtPort}:8080"
    Write-Info "Credentials: $Username / $Password"
    
    try {
        # Only stop/remove if we need to restart or if exists but not running
        $exists = podman ps -aq --filter "name=$ContainerName" 2>$null
        if ($exists) {
            $wasStopped = Stop-Container -Silent:$true
            $wasRemoved = Remove-Container -Silent:$true
            
            if ($wasStopped) {
                Write-Info "Stopped existing container"
            }
            if ($wasRemoved) {
                Write-Info "Removed existing container"
            }
        }
        
        # Build podman run command
        $podmanArgs = @(
            "run"
            "-d"
            "--name"
            $ContainerName
            "-p"
            "${CupsPort}:631"
            "-p"
            "${MgmtPort}:8080"
            "-e"
            "CUPS_USERNAME=$Username"
            "-e"
            "CUPS_PASSWORD=$Password"
            "-e"
            "SERVER_NAME=CUPS Print Server"
            "-e"
            "SSL_ENABLED=true"
            "-v"
            "${PWD}/addon-config:/config"
            "--restart"
            "unless-stopped"
        )
        
        # Add privileged mode if requested
        if ($Privileged) {
            $podmanArgs += "--privileged"
            Write-Info "Running in privileged mode (for USB printer support)"
        }
        
        $podmanArgs += $ImageName

        # Start new container
        Write-Info "Executing: podman $($podmanArgs -join ' ')"
        $containerId = & podman @podmanArgs
        
        if ($LASTEXITCODE -eq 0 -and $containerId) {
            Write-Info "Container started successfully"
            Write-Info "Container ID: $containerId"
            Write-Info "CUPS Web Interface: https://localhost:$CupsPort"
            Write-Info "Management Interface: http://localhost:$MgmtPort"
            Write-Info "Login with: $Username / $Password"
            
            # Wait a moment and check if container is still running
            Start-Sleep -Seconds 5
            $running = podman ps -q --filter "name=$ContainerName"
            if ($running) {
                Write-Info "Container is running healthy"
                Write-Info "Checking services status..."
                
                # Quick health check
                Start-Sleep -Seconds 3
                $healthCheck = podman exec $ContainerName ps aux | Select-String "cupsd|supervisord"
                if ($healthCheck) {
                    Write-Info "Services are running inside container"
                    Write-Info "You can now access:"
                    Write-Host "  - CUPS Interface: https://localhost:$CupsPort" -ForegroundColor Cyan
                    Write-Host "  - Management Interface: http://localhost:$MgmtPort" -ForegroundColor Cyan
                } else {
                    Write-Warning "Services may not be fully started yet"
                }
            }
            else {
                Write-Error "Container stopped unexpectedly, checking logs..."
                podman logs $ContainerName
                exit 1
            }
        }
        else {
            Write-Error "Failed to start container (Exit code: $LASTEXITCODE)"
            if ($containerId) {
                Write-Error "Output: $containerId"
            }
            exit 1
        }
    }
    catch {
        Write-Error "Failed to start container: $_"
        exit 1
    }
}

function Show-Logs {
    Write-Info "Showing logs for container: $ContainerName"
    try {
        podman logs -f $ContainerName
    }
    catch {
        Write-Error "Could not show logs: $_"
        exit 1
    }
}

function Clear-Resources {
    Write-Info "Cleaning up Podman resources"
    $null = Stop-Container
    $null = Remove-Container
    
    try {
        # Remove dangling images
        $danglingImages = podman images -f "dangling=true" -q
        if ($danglingImages) {
            Write-Info "Removing dangling images"
            podman rmi $danglingImages
        }
        
        Write-Info "Cleanup completed"
    }
    catch {
        Write-Warning "Cleanup had some issues: $_"
    }
}

function Show-Usage {
    Write-Host @"
HomeAssistant CUPS Podman Manager v2.0

Usage: .\run.ps1 [-Action <action>] [options]

Actions:
  build     - Build the Podman image
  run       - Build (if needed) and run container  
  stop      - Stop the container gracefully
  restart   - Restart the container
  logs      - Show container logs (follow mode)
  clean     - Stop and remove container + cleanup
  status    - Show comprehensive container and service status
  config    - Show current configuration
  shell     - Open interactive bash shell in container
  kill      - Force kill the container
  pause     - Pause the container
  unpause   - Unpause the container
  help      - Show this help message

Options:
  -ContainerName <name>    Container name (default: homeassistant-cups)
  -ImageName <name>        Podman image name (default: cups-addon:ha-integration)
  -CupsPort <port>         CUPS port mapping (default: 631)
  -MgmtPort <port>         Management port mapping (default: 8080)
  -Username <username>     CUPS username (default: print)
  -Password <password>     CUPS password (default: print)
  -Privileged              Run in privileged mode (for USB printer support)

Examples:
  .\run.ps1                                         # Build and run with defaults
  .\run.ps1 -Action build                           # Build the Podman image
  .\run.ps1 -Action run -CupsPort 8631 -Privileged # Run on different port with USB support
  .\run.ps1 -Action status                          # Show detailed status
  .\run.ps1 -Action shell                           # Open shell for debugging
  .\run.ps1 -Action logs                            # Monitor logs in real-time
  .\run.ps1 -Action clean                           # Full cleanup

Access URLs (when running):
  CUPS Interface: https://localhost:<CupsPort>
  Management Interface: http://localhost:<MgmtPort>

"@
}

function Show-Status {
    Write-Info "Container Status:"
    $containerStatus = podman ps -a --filter "name=$ContainerName" --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}"
    Write-Host $containerStatus
    
    Write-Info "`nImage Information:"
    $imageInfo = podman images | Select-String -Pattern $ImageName.Split(':')[0]
    Write-Host $imageInfo
    
    # Check if container is running and get more details
    $running = podman ps -q --filter "name=$ContainerName"
    if ($running) {
        Write-Info "`nServices Status:"
        try {
            $processes = podman exec $ContainerName ps aux
            
            # Check CUPS
            $cupsProcess = $processes | Select-String "cupsd"
            if ($cupsProcess) {
                Write-Host "CUPS daemon is running" -ForegroundColor Green
            } else {
                Write-Host "CUPS daemon is not running" -ForegroundColor Red
            }
            
            # Check Management API
            $apiProcess = $processes | Select-String "cups-management-api"
            if ($apiProcess) {
                Write-Host "Management API is running" -ForegroundColor Green
            } else {
                Write-Host "Management API is not running" -ForegroundColor Red
            }
            
            # Check Supervisor
            $supervisorProcess = $processes | Select-String "supervisord"
            if ($supervisorProcess) {
                Write-Host "Supervisor is running" -ForegroundColor Green
            } else {
                Write-Host "Supervisor is not running" -ForegroundColor Red
            }
            
            # Test web interfaces
            Write-Info "`nWeb Interface Tests:"
            try {
                $cupsResponse = podman exec $ContainerName curl -s -k -o /dev/null -w "%{http_code}" https://localhost:631
                if ($cupsResponse -eq "200" -or $cupsResponse -eq "401") {
                    Write-Host "CUPS web interface is responding (HTTP $cupsResponse)" -ForegroundColor Green
                } else {
                    Write-Host "Warning: CUPS web interface returned status: $cupsResponse" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "Warning: Could not test CUPS web interface" -ForegroundColor Yellow
            }
            
            try {
                $mgmtResponse = podman exec $ContainerName curl -s -o /dev/null -w "%{http_code}" http://localhost:8080
                if ($mgmtResponse -eq "200") {
                    Write-Host "Management interface is responding (HTTP $mgmtResponse)" -ForegroundColor Green
                } else {
                    Write-Host "Warning: Management interface returned status: $mgmtResponse" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "Warning: Could not test Management interface" -ForegroundColor Yellow
            }
            
        } catch {
            Write-Host "Warning: Could not check service status" -ForegroundColor Yellow
        }
        
        Write-Info "`nAccess Information:"
        Write-Host "CUPS Interface: https://localhost:$CupsPort" -ForegroundColor Cyan
        Write-Host "Management Interface: http://localhost:$MgmtPort" -ForegroundColor Cyan
        Write-Host "Username: $Username" -ForegroundColor Cyan
        
        Write-Info "`nContainer Resources:"
        $stats = podman stats $ContainerName --no-stream --format "table {{.CPUPerc}}`t{{.MemUsage}}`t{{.NetIO}}"
        Write-Host $stats
        
    } else {
        Write-Warning "Container is not running"
    }
}

function Kill-Container {
    Write-Warning "Force killing container: $ContainerName"
    try {
        $running = podman ps -q --filter "name=$ContainerName" 2>$null
        if ($running) {
            podman kill $ContainerName | Out-Null
            Write-Info "Container killed"
            return $true
        } else {
            Write-Warning "Container $ContainerName is not running"
            return $false
        }
    }
    catch {
        Write-Error "Could not kill container: $_"
        return $false
    }
}

function Pause-Container {
    Write-Info "Pausing container: $ContainerName"
    try {
        $running = podman ps -q --filter "name=$ContainerName" 2>$null
        if ($running) {
            podman pause $ContainerName | Out-Null
            Write-Info "Container paused"
            return $true
        } else {
            Write-Warning "Container $ContainerName is not running"
            return $false
        }
    }
    catch {
        Write-Error "Could not pause container: $_"
        return $false
    }
}

function Unpause-Container {
    Write-Info "Unpausing container: $ContainerName"
    try {
        podman unpause $ContainerName | Out-Null
        Write-Info "Container unpaused"
        return $true
    }
    catch {
        Write-Error "Could not unpause container: $_"
        return $false
    }
}

function Show-Config {
    Write-Info "Current Configuration:"
    Write-Host "Container Name: $ContainerName" -ForegroundColor Yellow
    Write-Host "Image Name: $ImageName" -ForegroundColor Yellow
    Write-Host "CUPS Port: $CupsPort" -ForegroundColor Yellow
    Write-Host "Management Port: $MgmtPort" -ForegroundColor Yellow
    Write-Host "Username: $Username" -ForegroundColor Yellow
    Write-Host "Privileged Mode: $($Privileged.IsPresent)" -ForegroundColor Yellow
    
    # Check if config directory exists
    $configDir = "${PWD}/addon-config"
    if (Test-Path $configDir) {
        Write-Info "`nConfiguration Directory: $configDir"
        $configFiles = Get-ChildItem $configDir -Recurse | Select-Object Name, Length, LastWriteTime
        $configFiles | Format-Table -AutoSize
    } else {
        Write-Info "`nConfiguration directory does not exist yet"
    }
}

function Open-Shell {
    Write-Info "Opening interactive shell in container: $ContainerName"
    try {
        $running = podman ps -q --filter "name=$ContainerName"
        if ($running) {
            Write-Info "Starting bash shell... (type 'exit' to return)"
            podman exec -it $ContainerName bash
        } else {
            Write-Error "Container is not running"
        }
    }
    catch {
        Write-Error "Could not open shell: $_"
    }
}

# Main script logic
Write-Info "HomeAssistant CUPS Podman Manager v2.0"
Write-Info "Action: $Action"

switch ($Action) {
    "build" {
        Build-Image
    }
    "run" {
        # Check if image exists, build if not
        $imageExists = podman images -q $ImageName
        if (-not $imageExists) {
            Write-Warning "Image $ImageName not found, building first..."
            Build-Image
        }
        Start-Container
    }
    "stop" {
        $null = Stop-Container
    }
    "restart" {
        Write-Info "Restarting container..."
        $running = podman ps -q --filter "name=$ContainerName" 2>$null
        if ($running) {
            $null = Stop-Container
            Start-Sleep -Seconds 2
            Start-Container -ForceRestart:$true
        } else {
            Write-Info "Container is not running, starting it..."
            Start-Container
        }
    }
    "logs" {
        Show-Logs
    }
    "clean" {
        Clear-Resources
    }
    "status" {
        Show-Status
    }
    "config" {
        Show-Config
    }
    "shell" {
        Open-Shell
    }
    "kill" {
        $null = Kill-Container
    }
    "pause" {
        $null = Pause-Container
    }
    "unpause" {
        $null = Unpause-Container
    }
    "help" {
        Show-Usage
    }
    default {
        Write-Error "Unknown action: $Action"
        Show-Usage
        exit 1
    }
}

Write-Info "Done!"
