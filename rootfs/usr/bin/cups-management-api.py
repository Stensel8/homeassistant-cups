#!/usr/bin/env python3
"""
CUPS Management API Server for Home Assistant Add-on
Provides REST API for managing CUPS service and configuration
"""

from flask import Flask, request, jsonify, send_from_directory
import subprocess
import json
import os
import signal
import sys
from datetime import datetime

app = Flask(__name__)

# Configuration paths
CONFIG_PATH = '/data/options.json'
CUPS_CONFIG_PATH = '/config/cups/cupsd.conf'
LOG_FILE = '/var/log/cups/error_log'

def load_addon_config():
    """Load Home Assistant addon configuration"""
    try:
        if os.path.exists(CONFIG_PATH):
            with open(CONFIG_PATH, 'r') as f:
                return json.load(f)
    except Exception as e:
        print(f"[ERROR] Failed to load config: {e}")
    
    # Return default config
    return {
        "cups_username": "print",
        "cups_password": "print",
        "cups_port": 631,
        "management_port": 8080,
        "server_name": "CUPS Print Server",
        "log_level": "info",
        "max_jobs": 100,
        "ssl_enabled": True
    }

def save_addon_config(config):
    """Save Home Assistant addon configuration"""
    try:
        os.makedirs(os.path.dirname(CONFIG_PATH), exist_ok=True)
        with open(CONFIG_PATH, 'w') as f:
            json.dump(config, f, indent=2)
        return True
    except Exception as e:
        print(f"[ERROR] Failed to save config: {e}")
        return False

def run_command(cmd, shell=True):
    """Execute shell command and return output"""
    try:
        result = subprocess.run(cmd, shell=shell, capture_output=True, text=True, timeout=30)
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return -1, "", "Command timed out"
    except Exception as e:
        return -1, "", str(e)

@app.route('/')
def index():
    """Serve the main management interface"""
    return send_from_directory('/var/www/html', 'index.html')

@app.route('/api/status')
def get_status():
    """Get current CUPS service status"""
    try:
        # Check if CUPS is running
        code, stdout, stderr = run_command("pgrep -x cupsd")
        if code == 0:
            cups_status = "✅ RUNNING"
            pid = stdout.strip()
        else:
            cups_status = "❌ STOPPED"
            pid = "N/A"
        
        # Check if avahi is running
        code, stdout, stderr = run_command("pgrep -x avahi-daemon")
        avahi_status = "✅ RUNNING" if code == 0 else "❌ STOPPED"
        
        # Check if dbus is running
        code, stdout, stderr = run_command("pgrep -x dbus-daemon")
        dbus_status = "✅ RUNNING" if code == 0 else "❌ STOPPED"
        
        # Get system info
        code, uptime, _ = run_command("uptime")
        code, memory, _ = run_command("free -h | grep Mem")
        
        status_info = f"""
🖨️ CUPS Service Status - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
═══════════════════════════════════════════════════════════════

📋 Service Status:
   • CUPS Daemon: {cups_status} (PID: {pid})
   • Avahi mDNS: {avahi_status}
   • D-Bus: {dbus_status}

💾 System Info:
   • Uptime: {uptime.strip() if uptime else 'Unknown'}
   • Memory: {memory.strip() if memory else 'Unknown'}

🌐 Network:
   • CUPS Port: 631
   • Management Port: 8080
   • Web Interface: http://localhost:631
        """
        
        return status_info.strip()
        
    except Exception as e:
        return f"❌ Error getting status: {str(e)}"

@app.route('/api/service/<action>', methods=['POST'])
def service_control(action):
    """Control CUPS service (start/stop/restart)"""
    try:
        if action == 'start':
            # Start required services
            run_command("mkdir -p /var/run/dbus")
            code1, out1, err1 = run_command("dbus-daemon --system --fork")
            
            run_command("mkdir -p /var/run/avahi-daemon")
            code2, out2, err2 = run_command("avahi-daemon --daemonize")
            
            code3, out3, err3 = run_command("cupsd")
            
            if code3 == 0:
                return "✅ CUPS service started successfully"
            else:
                return f"❌ Failed to start CUPS: {err3}"
                
        elif action == 'stop':
            # Stop services
            run_command("killall cupsd")
            run_command("killall avahi-daemon")
            return "⏹️ CUPS service stopped"
            
        elif action == 'restart':
            # Restart services
            run_command("killall cupsd")
            run_command("killall avahi-daemon")
            
            # Wait a moment
            import time
            time.sleep(2)
            
            # Start again
            run_command("dbus-daemon --system --fork")
            run_command("avahi-daemon --daemonize")
            code, out, err = run_command("cupsd")
            
            if code == 0:
                return "🔄 CUPS service restarted successfully"
            else:
                return f"❌ Failed to restart CUPS: {err}"
                
        else:
            return f"❌ Unknown action: {action}"
            
    except Exception as e:
        return f"❌ Error executing {action}: {str(e)}"

@app.route('/api/config', methods=['GET', 'POST'])
def config_management():
    """Handle configuration get/set"""
    if request.method == 'GET':
        # Return current configuration
        config = load_addon_config()
        return jsonify(config)
        
    elif request.method == 'POST':
        # Update configuration
        try:
            new_config = request.get_json()
            current_config = load_addon_config()
            
            # Update with new values
            current_config.update(new_config)
            
            # Save configuration
            if save_addon_config(current_config):
                
                # If username/password changed, update system user
                if 'cups_username' in new_config and 'cups_password' in new_config:
                    username = new_config['cups_username']
                    password = new_config['cups_password']
                    
                    # Create/update user
                    run_command(f"useradd --groups=sudo,lp,lpadmin --create-home --home-dir=/home/{username} --shell=/bin/bash {username} 2>/dev/null || true")
                    run_command(f"echo '{username}:{password}' | chpasswd")
                    
                return jsonify({"status": "success", "message": "Configuration saved successfully"})
            else:
                return jsonify({"status": "error", "message": "Failed to save configuration"}), 500
                
        except Exception as e:
            return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/api/logs')
def get_logs():
    """Get CUPS log files"""
    try:
        logs = []
        
        # CUPS error log
        if os.path.exists('/var/log/cups/error_log'):
            code, output, _ = run_command("tail -50 /var/log/cups/error_log")
            if output:
                logs.append("=== CUPS Error Log ===")
                logs.append(output)
        
        # CUPS access log
        if os.path.exists('/var/log/cups/access_log'):
            code, output, _ = run_command("tail -20 /var/log/cups/access_log")
            if output:
                logs.append("\n=== CUPS Access Log ===")
                logs.append(output)
        
        # System logs
        code, output, _ = run_command("journalctl -u cups -n 20 --no-pager")
        if output:
            logs.append("\n=== System Log ===")
            logs.append(output)
        
        return '\n'.join(logs) if logs else "No logs available"
        
    except Exception as e:
        return f"Error reading logs: {str(e)}"

@app.route('/api/system-info')
def get_system_info():
    """Get system information"""
    try:
        info = []
        
        # System info
        code, output, _ = run_command("uname -a")
        if output:
            info.append(f"System: {output.strip()}")
        
        # CUPS version
        code, output, _ = run_command("cupsd -v")
        if output:
            info.append(f"CUPS Version: {output.strip()}")
        
        # Disk usage
        code, output, _ = run_command("df -h /")
        if output:
            info.append(f"Disk Usage:\n{output}")
        
        # Network interfaces
        code, output, _ = run_command("ip addr show")
        if output:
            info.append(f"Network Interfaces:\n{output}")
        
        return '\n\n'.join(info)
        
    except Exception as e:
        return f"Error getting system info: {str(e)}"

@app.route('/cups/')
def cups_proxy():
    """Proxy to CUPS web interface"""
    return """
    <script>
        // Redirect to CUPS interface
        window.open('http://localhost:631', '_blank');
        window.history.back();
    </script>
    <p>Opening CUPS web interface... <a href="http://localhost:631" target="_blank">Click here if it doesn't open automatically</a></p>
    """

def signal_handler(sig, frame):
    """Handle shutdown signals"""
    print('[INFO] Management API shutting down...')
    sys.exit(0)

if __name__ == '__main__':
    # Setup signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Get port from config
    config = load_addon_config()
    port = config.get('management_port', 8080)
    
    logger.info(f"Starting CUPS Management API on port {port}")
    app.run(host='0.0.0.0', port=port, debug=False)
