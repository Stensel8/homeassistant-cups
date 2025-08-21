#!/usr/bin/env python3

from flask import Flask, request, jsonify, render_template_string
import subprocess
import json
import os
import signal
import sys
import time

app = Flask(__name__)

def load_addon_config():
    """Load addon configuration with defaults"""
    default_config = {
        'cups_username': 'print',
        'cups_password': 'print',
        'management_port': 8080
    }
    
    try:
        with open('/data/options.json', 'r') as f:
            config = json.load(f)
            return {**default_config, **config}
    except (FileNotFoundError, json.JSONDecodeError):
        return default_config

def run_command(cmd, shell=False):
    """Execute command and return result"""
    try:
        if shell:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
        else:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        return result.returncode == 0, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return False, "", "Command timeout"
    except Exception as e:
        return False, "", str(e)

def get_printers():
    """Get list of configured printers"""
    success, output, error = run_command(['lpstat', '-p'])
    if not success:
        return []
    
    printers = []
    for line in output.split('\n'):
        if line.startswith('printer'):
            parts = line.split()
            if len(parts) >= 2:
                printers.append({
                    'name': parts[1],
                    'status': 'idle' if 'idle' in line else 'busy'
                })
    return printers

def get_jobs():
    """Get list of print jobs"""
    success, output, error = run_command(['lpstat', '-o'])
    if not success:
        return []
    
    jobs = []
    for line in output.split('\n'):
        if line.strip():
            parts = line.split()
            if len(parts) >= 4:
                jobs.append({
                    'id': parts[0].split('-')[-1] if '-' in parts[0] else parts[0],
                    'printer': parts[0].split('-')[0] if '-' in parts[0] else 'unknown',
                    'user': parts[1] if len(parts) > 1 else 'unknown',
                    'size': parts[2] if len(parts) > 2 else '0',
                    'status': ' '.join(parts[3:]) if len(parts) > 3 else 'unknown'
                })
    return jobs

@app.route('/')
def index():
    """Main management interface"""
    template = '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CUPS Management Interface</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        body { background-color: #f8f9fa; }
        .navbar { background-color: #0056b3; }
        .card { border: none; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .status-indicator { width: 10px; height: 10px; border-radius: 50%; display: inline-block; margin-right: 5px; }
        .status-active { background-color: #28a745; }
        .status-idle { background-color: #ffc107; }
        .status-error { background-color: #dc3545; }
    </style>
</head>
<body>
    <nav class="navbar navbar-dark">
        <div class="container">
            <span class="navbar-brand">CUPS Management Interface</span>
            <span class="navbar-text">Print Server Administration</span>
        </div>
    </nav>

    <div class="container mt-4">
        <div class="row">
            <div class="col-md-6">
                <div class="card mb-4">
                    <div class="card-header"><h5>System Status</h5></div>
                    <div class="card-body">
                        <div id="system-status">
                            <div class="d-flex align-items-center mb-2">
                                <span class="status-indicator status-active"></span>
                                <span>CUPS Daemon: Active</span>
                            </div>
                            <div class="d-flex align-items-center">
                                <span class="status-indicator status-active"></span>
                                <span>Management API: Active</span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-md-6">
                <div class="card mb-4">
                    <div class="card-header"><h5>Quick Actions</h5></div>
                    <div class="card-body">
                        <a href="https://localhost:631" target="_blank" class="btn btn-primary me-2">CUPS Web Interface</a>
                        <button class="btn btn-secondary" onclick="refreshData()">Refresh Data</button>
                    </div>
                </div>
            </div>
        </div>

        <div class="row">
            <div class="col-md-6">
                <div class="card">
                    <div class="card-header"><h5>Printers</h5></div>
                    <div class="card-body">
                        <div id="printers-list">
                            <div class="text-muted">Loading printers...</div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-md-6">
                <div class="card">
                    <div class="card-header"><h5>Print Jobs</h5></div>
                    <div class="card-body">
                        <div id="jobs-list">
                            <div class="text-muted">Loading jobs...</div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        function refreshData() {
            loadPrinters();
            loadJobs();
        }

        function loadPrinters() {
            fetch('/api/printers')
                .then(response => response.json())
                .then(data => {
                    const container = document.getElementById('printers-list');
                    if (data.printers && data.printers.length > 0) {
                        container.innerHTML = data.printers.map(printer => 
                            `<div class="d-flex align-items-center mb-2">
                                <span class="status-indicator ${printer.status === 'idle' ? 'status-idle' : 'status-active'}"></span>
                                <span>${printer.name} (${printer.status})</span>
                            </div>`
                        ).join('');
                    } else {
                        container.innerHTML = '<div class="text-muted">No printers configured</div>';
                    }
                })
                .catch(error => {
                    document.getElementById('printers-list').innerHTML = '<div class="text-danger">Failed to load printers</div>';
                });
        }

        function loadJobs() {
            fetch('/api/jobs')
                .then(response => response.json())
                .then(data => {
                    const container = document.getElementById('jobs-list');
                    if (data.jobs && data.jobs.length > 0) {
                        container.innerHTML = data.jobs.map(job => 
                            `<div class="mb-2">
                                <small class="text-muted">Job ${job.id}</small><br>
                                <strong>${job.printer}</strong> - ${job.user}<br>
                                <small>${job.status}</small>
                            </div>`
                        ).join('');
                    } else {
                        container.innerHTML = '<div class="text-muted">No active jobs</div>';
                    }
                })
                .catch(error => {
                    document.getElementById('jobs-list').innerHTML = '<div class="text-danger">Failed to load jobs</div>';
                });
        }

        document.addEventListener('DOMContentLoaded', refreshData);
        setInterval(refreshData, 30000);
    </script>
</body>
</html>'''
    return render_template_string(template)

@app.route('/api/status')
def api_status():
    """System status API endpoint"""
    cups_running = subprocess.run(['pgrep', 'cupsd'], capture_output=True).returncode == 0
    
    return jsonify({
        'status': 'running',
        'cups_daemon': cups_running,
        'management_api': True,
        'timestamp': time.time()
    })

@app.route('/api/printers')
def api_printers():
    """Printers API endpoint"""
    printers = get_printers()
    return jsonify({'printers': printers})

@app.route('/api/jobs')
def api_jobs():
    """Jobs API endpoint"""
    jobs = get_jobs()
    return jsonify({'jobs': jobs})

def signal_handler(sig, frame):
    print('[INFO] Shutting down Management API')
    sys.exit(0)

if __name__ == '__main__':
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    config = load_addon_config()
    port = config.get('management_port', 8080)
    
    print(f'[INFO] Starting CUPS Management API on port {port}')
    app.run(host='0.0.0.0', port=port, debug=False)
