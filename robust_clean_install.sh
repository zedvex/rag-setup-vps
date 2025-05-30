#!/bin/bash

# Laika Dynamics RAG System - Robust Clean Install Script
# Fixed version that doesn't kill itself during cleanup
set -e

# Signal handling
trap 'echo "Installation interrupted but continuing..."; sleep 2' INT TERM

# Configuration
PROJECT_DIR="$HOME/laika-dynamics-rag"
VENV_NAME="laika-rag-env"
API_PORT="8000"
UI_PORT="3000"
QDRANT_PORT="6333"
VPS_IP="194.238.17.65"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

header() {
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║ $1${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Safe cleanup function that won't kill this script
safe_cleanup() {
    header "🧹 SAFE SYSTEM CLEANUP"
    
    # Disable exit on error for cleanup
    set +e
    
    log "Stopping specific application processes..."
    
    # Kill specific processes by name (not pattern matching that could match this script)
    pkill -f "uvicorn.*api.main" 2>/dev/null
    pkill -f "python.*ui_server.py" 2>/dev/null  
    pkill -f "gunicorn.*api.main" 2>/dev/null
    pkill -f "fastapi" 2>/dev/null
    
    # Kill processes by port (more reliable)
    log "Freeing up ports..."
    fuser -k $API_PORT/tcp 2>/dev/null
    fuser -k $UI_PORT/tcp 2>/dev/null  
    fuser -k $QDRANT_PORT/tcp 2>/dev/null
    
    # Wait for processes to die
    sleep 3
    
    log "Removing old project directory..."
    if [ -d "$PROJECT_DIR" ]; then
        rm -rf "$PROJECT_DIR"
        log "✅ Removed $PROJECT_DIR"
    fi
    
    # Re-enable exit on error
    set -e
    
    log "✅ Safe cleanup completed!"
}

# System setup
setup_system() {
    header "🔧 SYSTEM SETUP"
    
    log "Updating system packages..."
    if command -v dnf &> /dev/null; then
        sudo dnf update -y >/dev/null 2>&1
        sudo dnf install -y curl wget git python3 python3-pip python3-venv gcc sqlite firewalld psmisc >/dev/null 2>&1
    elif command -v yum &> /dev/null; then
        sudo yum update -y >/dev/null 2>&1
        sudo yum install -y curl wget git python3 python3-pip gcc sqlite firewalld psmisc >/dev/null 2>&1
    fi
    
    log "✅ System packages updated"
}

# Firewall configuration
configure_firewall() {
    header "🔥 FIREWALL CONFIGURATION"
    
    if command -v firewall-cmd &> /dev/null; then
        log "Configuring firewalld..."
        sudo systemctl enable firewalld >/dev/null 2>&1
        sudo systemctl start firewalld >/dev/null 2>&1
        
        sudo firewall-cmd --permanent --add-port=$API_PORT/tcp >/dev/null 2>&1
        sudo firewall-cmd --permanent --add-port=$UI_PORT/tcp >/dev/null 2>&1
        sudo firewall-cmd --permanent --add-port=$QDRANT_PORT/tcp >/dev/null 2>&1
        sudo firewall-cmd --reload >/dev/null 2>&1
        
        log "✅ Firewall configured"
    fi
}

# Create project structure
create_project() {
    header "📁 PROJECT CREATION"
    
    log "Creating project directory: $PROJECT_DIR"
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    mkdir -p {data,api,ui,logs,configs}
    
    log "✅ Project structure created"
}

# Setup Python environment
setup_python() {
    header "🐍 PYTHON SETUP"
    
    cd "$PROJECT_DIR"
    
    log "Creating Python virtual environment..."
    python3 -m venv $VENV_NAME
    source $VENV_NAME/bin/activate
    
    log "Installing dependencies..."
    pip install --upgrade pip >/dev/null 2>&1
    pip install fastapi uvicorn gunicorn psutil requests >/dev/null 2>&1
    
    log "✅ Python environment ready"
}

# Create project files
create_files() {
    header "📄 CREATING PROJECT FILES"
    
    cd "$PROJECT_DIR"
    
    # Management script
    cat > manage.sh << 'EOF'
#!/bin/bash
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_PORT="8000"
UI_PORT="3000"
VPS_IP="194.238.17.65"

start_api() {
    cd "$PROJECT_DIR"
    source laika-rag-env/bin/activate
    fuser -k $API_PORT/tcp 2>/dev/null || true
    sleep 2
    nohup gunicorn api.main:app -w 2 -k uvicorn.workers.UvicornWorker -b 0.0.0.0:$API_PORT --daemon --pid api.pid --log-file logs/api.log
    echo "✅ API started on port $API_PORT"
}

start_ui() {
    cd "$PROJECT_DIR"  
    fuser -k $UI_PORT/tcp 2>/dev/null || true
    sleep 2
    nohup python3 ui_server.py > logs/ui.log 2>&1 &
    echo $! > ui.pid
    echo "✅ UI started on port $UI_PORT"
}

stop_services() {
    [ -f api.pid ] && kill $(cat api.pid) 2>/dev/null && rm -f api.pid
    [ -f ui.pid ] && kill $(cat ui.pid) 2>/dev/null && rm -f ui.pid
    fuser -k $API_PORT/tcp 2>/dev/null || true
    fuser -k $UI_PORT/tcp 2>/dev/null || true
    echo "✅ Services stopped"
}

show_status() {
    echo "🚀 Laika Dynamics RAG System Status"
    echo "==================================="
    
    if [ -f api.pid ] && kill -0 $(cat api.pid) 2>/dev/null; then
        echo "✅ API Server: Running (PID: $(cat api.pid))"
    else
        echo "❌ API Server: Not running"
    fi
    
    if [ -f ui.pid ] && kill -0 $(cat ui.pid) 2>/dev/null; then
        echo "✅ UI Server: Running (PID: $(cat ui.pid))"
    else
        echo "❌ UI Server: Not running"  
    fi
    
    echo ""
    echo "🌍 Access URLs:"
    echo "  🌐 Web Interface: http://$VPS_IP:$UI_PORT"
    echo "  📡 API Endpoint:  http://$VPS_IP:$API_PORT"
    echo "  📚 API Docs:      http://$VPS_IP:$API_PORT/docs"
    echo ""
}

show_logs() {
    echo "📝 Recent Logs"
    echo "=============="
    echo ""
    echo "=== API Logs ==="
    [ -f logs/api.log ] && tail -15 logs/api.log || echo "No API logs"
    echo ""
    echo "=== UI Logs ==="
    [ -f logs/ui.log ] && tail -15 logs/ui.log || echo "No UI logs"
}

case "${1:-start}" in
    start)
        echo "🚀 Starting Laika Dynamics RAG System..."
        mkdir -p logs
        start_api
        start_ui
        sleep 3
        show_status
        ;;
    stop) stop_services ;;
    restart) stop_services; sleep 2; "$0" start ;;
    status) show_status ;;
    logs) show_logs ;;
    *) 
        echo "Usage: $0 {start|stop|restart|status|logs}"
        exit 1
        ;;
esac
EOF

    chmod +x manage.sh

    # UI Server
    cat > ui_server.py << 'EOF'
#!/usr/bin/env python3
import http.server
import socketserver
import os
from pathlib import Path

PORT = 3000
UI_DIR = "ui"

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=UI_DIR, **kwargs)
    
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        super().end_headers()

def main():
    os.chdir(Path(__file__).parent)
    
    if not os.path.exists(UI_DIR):
        print(f"❌ {UI_DIR} directory not found!")
        exit(1)
    
    print(f"🌐 UI server starting on port {PORT}")
    print(f"🔗 Access: http://194.238.17.65:{PORT}")
    
    with socketserver.TCPServer(("0.0.0.0", PORT), Handler) as httpd:
        httpd.serve_forever()

if __name__ == "__main__":
    main()
EOF

    chmod +x ui_server.py

    # API
    mkdir -p api
    cat > api/__init__.py << 'EOF'
# API Package
EOF

    cat > api/main.py << 'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
import platform
import psutil
import socket
from datetime import datetime

app = FastAPI(title="Laika Dynamics RAG API", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    return {
        "message": "🚀 Laika Dynamics RAG API is operational!",
        "status": "active",
        "version": "2.0.0",
        "timestamp": datetime.now().isoformat()
    }

@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "version": "2.0.0",
        "timestamp": datetime.now().isoformat()
    }

@app.get("/system")
async def system_info():
    memory = psutil.virtual_memory()
    disk = psutil.disk_usage('/')
    
    return {
        "system": {
            "hostname": socket.gethostname(),
            "os": platform.system(),
            "distribution": platform.platform(),
            "python_version": platform.python_version(),
            "architecture": platform.machine()
        },
        "resources": {
            "cpu_cores": psutil.cpu_count(),
            "cpu_percent": psutil.cpu_percent(interval=1),
            "memory_total_gb": round(memory.total / (1024**3), 2),
            "memory_used_gb": round(memory.used / (1024**3), 2),
            "memory_percent": memory.percent,
            "disk_total_gb": round(disk.total / (1024**3), 2),
            "disk_used_gb": round((disk.total - disk.free) / (1024**3), 2),
            "disk_percent": round(((disk.total - disk.free) / disk.total) * 100, 2)
        },
        "timestamp": datetime.now().isoformat()
    }

@app.get("/ui", response_class=HTMLResponse)
async def ui_redirect():
    return """
    <html>
    <head>
        <title>Redirecting to UI</title>
        <meta http-equiv="refresh" content="0; url=http://194.238.17.65:3000">
    </head>
    <body>
        <h1>🚀 Laika Dynamics</h1>
        <p>Redirecting to <a href="http://194.238.17.65:3000">Web Interface</a></p>
    </body>
    </html>
    """
EOF

    # Simple but effective UI
    mkdir -p ui
    cat > ui/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Laika Dynamics RAG System</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: linear-gradient(135deg, #667eea, #764ba2); min-height: 100vh; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 40px; border-radius: 15px; box-shadow: 0 20px 40px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; text-align: center; margin-bottom: 30px; font-size: 2.5rem; }
        .status { background: #27ae60; color: white; padding: 20px; border-radius: 10px; text-align: center; margin: 20px 0; font-size: 1.2rem; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(350px, 1fr)); gap: 20px; margin: 30px 0; }
        .card { background: #f8f9fa; padding: 25px; border-radius: 10px; border-left: 4px solid #3498db; }
        .card h3 { color: #2c3e50; margin-bottom: 15px; display: flex; align-items: center; gap: 10px; }
        .url { background: #e9ecef; padding: 12px; border-radius: 5px; margin: 8px 0; }
        .url a { color: #3498db; text-decoration: none; font-family: monospace; }
        .url a:hover { text-decoration: underline; }
        #apiStatus { padding: 10px 20px; border-radius: 20px; margin: 10px; font-weight: bold; }
        .online { background: #27ae60; color: white; }
        .offline { background: #e74c3c; color: white; }
        ul { list-style: none; padding: 0; }
        li { padding: 8px 0; border-bottom: 1px solid #dee2e6; }
        li:last-child { border-bottom: none; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Laika Dynamics RAG System</h1>
        <div class="status">✅ System Online & Ready for Global Access</div>
        
        <div style="text-align: center; margin: 20px 0;">
            <div id="apiStatus">Checking API...</div>
        </div>
        
        <div class="grid">
            <div class="card">
                <h3>🌍 Global Access URLs</h3>
                <div class="url"><strong>Web Interface:</strong><br><a href="http://194.238.17.65:3000" target="_blank">http://194.238.17.65:3000</a></div>
                <div class="url"><strong>API Endpoint:</strong><br><a href="http://194.238.17.65:8000" target="_blank">http://194.238.17.65:8000</a></div>
                <div class="url"><strong>API Documentation:</strong><br><a href="http://194.238.17.65:8000/docs" target="_blank">http://194.238.17.65:8000/docs</a></div>
                <div class="url"><strong>System Information:</strong><br><a href="http://194.238.17.65:8000/system" target="_blank">http://194.238.17.65:8000/system</a></div>
            </div>
            
            <div class="card">
                <h3>🤖 AI Features</h3>
                <ul>
                    <li>✨ Synthetic business data generation</li>
                    <li>🔍 Vector database with Qdrant</li>
                    <li>🧠 Local AI models with Ollama</li>
                    <li>📡 RESTful API interface</li>
                    <li>🌐 Global internet accessibility</li>
                    <li>🔧 Enterprise AlmaLinux setup</li>
                </ul>
            </div>
            
            <div class="card">
                <h3>🎯 Enterprise Ready</h3>
                <p>Complete RAG (Retrieval Augmented Generation) system for web contracting data analysis. Built on AlmaLinux 9 with Python 3.11, accessible globally.</p>
                <ul>
                    <li>🏢 Enterprise architecture</li>
                    <li>⚡ High performance</li>
                    <li>🔒 Security first</li>
                    <li>🌐 Global access</li>
                </ul>
            </div>
            
            <div class="card">
                <h3>⚡ System Status</h3>
                <div id="systemInfo">Loading...</div>
            </div>
        </div>
    </div>

    <script>
        async function checkAPI() {
            try {
                const response = await fetch('http://194.238.17.65:8000/health');
                const data = await response.json();
                document.getElementById('apiStatus').textContent = '✅ API Online';
                document.getElementById('apiStatus').className = 'online';
            } catch (error) {
                document.getElementById('apiStatus').textContent = '❌ API Offline';
                document.getElementById('apiStatus').className = 'offline';
            }
        }

        async function loadSystemInfo() {
            try {
                const response = await fetch('http://194.238.17.65:8000/system');
                const data = await response.json();
                document.getElementById('systemInfo').innerHTML = `
                    <p><strong>OS:</strong> ${data.system?.distribution || 'Unknown'}</p>
                    <p><strong>Python:</strong> ${data.system?.python_version || 'Unknown'}</p>
                    <p><strong>CPU:</strong> ${data.resources?.cpu_cores || 0} cores</p>
                    <p><strong>Memory:</strong> ${data.resources?.memory_used_gb || 0}GB / ${data.resources?.memory_total_gb || 0}GB</p>
                    <p><strong>Hostname:</strong> ${data.system?.hostname || 'Unknown'}</p>
                `;
            } catch (error) {
                document.getElementById('systemInfo').innerHTML = '<p>System info unavailable</p>';
            }
        }

        // Initialize
        checkAPI();
        loadSystemInfo();
        setInterval(checkAPI, 30000);
        setInterval(loadSystemInfo, 60000);
    </script>
</body>
</html>
EOF

    log "✅ All project files created"
}

# Main installation
main() {
    header "🚀 LAIKA DYNAMICS RAG - ROBUST INSTALL"
    
    info "VPS IP: $VPS_IP"
    info "Project: $PROJECT_DIR"
    
    safe_cleanup
    setup_system
    configure_firewall  
    create_project
    setup_python
    create_files
    
    header "✅ INSTALLATION COMPLETE!"
    
    info ""
    info "🎉 System ready! Next steps:"
    info "  cd $PROJECT_DIR"
    info "  ./manage.sh start"
    info ""
    info "🌍 Access URLs:"
    info "  🌐 Web: http://$VPS_IP:$UI_PORT" 
    info "  📡 API: http://$VPS_IP:$API_PORT"
    info ""
    info "🔧 Commands:"
    info "  ./manage.sh start    - Start services"
    info "  ./manage.sh stop     - Stop services"
    info "  ./manage.sh status   - Check status"
    info "  ./manage.sh logs     - View logs"
    info ""
}

main "$@" 