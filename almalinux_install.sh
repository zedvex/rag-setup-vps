#!/bin/bash

# Laika Dynamics RAG System - AlmaLinux Optimized Install
# Fixed for AlmaLinux 9 package differences
set -e

# Configuration
PROJECT_DIR="$HOME/laika-dynamics-rag"
VENV_NAME="laika-rag-env"
API_PORT="8000"
UI_PORT="3000"
VPS_IP="194.238.17.65"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

header() {
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║ $1${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Quick cleanup
quick_cleanup() {
    header "🧹 QUICK CLEANUP"
    
    set +e
    log "Stopping services and freeing ports..."
    pkill -f "uvicorn.*api.main" 2>/dev/null
    pkill -f "python.*ui_server.py" 2>/dev/null
    pkill -f "gunicorn.*api.main" 2>/dev/null
    fuser -k $API_PORT/tcp 2>/dev/null
    fuser -k $UI_PORT/tcp 2>/dev/null
    
    if [ -d "$PROJECT_DIR" ]; then
        rm -rf "$PROJECT_DIR"
        log "✅ Removed old project"
    fi
    set -e
}

# AlmaLinux specific system setup
setup_almalinux() {
    header "🔧 ALMALINUX SYSTEM SETUP"
    
    log "Installing AlmaLinux packages..."
    
    # Enable EPEL for additional packages
    sudo dnf install -y epel-release >/dev/null 2>&1
    
    # Install core packages (python3-venv doesn't exist on AlmaLinux - venv is built into python3)
    sudo dnf install -y \
        curl wget git \
        python3 python3-pip \
        gcc sqlite \
        firewalld psmisc \
        >/dev/null 2>&1
    
    log "✅ AlmaLinux packages installed"
}

# Configure firewall
setup_firewall() {
    header "🔥 FIREWALL SETUP"
    
    log "Configuring firewalld..."
    sudo systemctl enable firewalld >/dev/null 2>&1
    sudo systemctl start firewalld >/dev/null 2>&1
    
    sudo firewall-cmd --permanent --add-port=$API_PORT/tcp >/dev/null 2>&1
    sudo firewall-cmd --permanent --add-port=$UI_PORT/tcp >/dev/null 2>&1
    sudo firewall-cmd --reload >/dev/null 2>&1
    
    log "✅ Firewall configured"
}

# Create project
create_project() {
    header "📁 PROJECT SETUP"
    
    log "Creating project structure..."
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    mkdir -p {api,ui,logs}
    
    log "✅ Project structure created"
}

# Python setup for AlmaLinux
setup_python() {
    header "🐍 PYTHON ENVIRONMENT"
    
    cd "$PROJECT_DIR"
    
    log "Creating virtual environment (AlmaLinux style)..."
    python3 -m venv $VENV_NAME
    source $VENV_NAME/bin/activate
    
    log "Installing Python packages..."
    pip install --upgrade pip >/dev/null 2>&1
    pip install fastapi uvicorn gunicorn psutil >/dev/null 2>&1
    
    log "✅ Python environment ready"
}

# Create all project files
create_files() {
    header "📄 CREATING FILES"
    
    cd "$PROJECT_DIR"
    
    # Simple management script
    cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source laika-rag-env/bin/activate

# Function to start API
start_api() {
    fuser -k 8000/tcp 2>/dev/null || true
    sleep 1
    nohup gunicorn api.main:app -w 2 -k uvicorn.workers.UvicornWorker -b 0.0.0.0:8000 --daemon --pid api.pid --log-file logs/api.log
    echo "✅ API started"
}

# Function to start UI  
start_ui() {
    fuser -k 3000/tcp 2>/dev/null || true
    sleep 1
    nohup python3 ui_server.py > logs/ui.log 2>&1 &
    echo $! > ui.pid
    echo "✅ UI started"
}

# Start services
mkdir -p logs
start_api
start_ui

echo ""
echo "🚀 Laika Dynamics RAG System Started!"
echo "🌐 Web Interface: http://194.238.17.65:3000"
echo "📡 API Endpoint:  http://194.238.17.65:8000"
echo "📚 API Docs:      http://194.238.17.65:8000/docs"
EOF

    # Stop script
    cat > stop.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"

[ -f api.pid ] && kill $(cat api.pid) 2>/dev/null && rm -f api.pid
[ -f ui.pid ] && kill $(cat ui.pid) 2>/dev/null && rm -f ui.pid
fuser -k 8000/tcp 2>/dev/null || true
fuser -k 3000/tcp 2>/dev/null || true

echo "✅ Services stopped"
EOF

    # Status script
    cat > status.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"

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
echo "  🌐 Web Interface: http://194.238.17.65:3000"
echo "  📡 API Endpoint:  http://194.238.17.65:8000"
echo "  📚 API Docs:      http://194.238.17.65:8000/docs"
EOF

    # Logs script
    cat > logs.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"

echo "📝 Recent Logs"
echo "=============="
echo ""
echo "=== API Logs ==="
[ -f logs/api.log ] && tail -20 logs/api.log || echo "No API logs"
echo ""
echo "=== UI Logs ==="
[ -f logs/ui.log ] && tail -20 logs/ui.log || echo "No UI logs"
EOF

    chmod +x start.sh stop.sh status.sh logs.sh

    # UI Server
    cat > ui_server.py << 'EOF'
#!/usr/bin/env python3
import http.server
import socketserver
import os

PORT = 3000
UI_DIR = "ui"

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=UI_DIR, **kwargs)
    
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        super().end_headers()

def main():
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
        "timestamp": datetime.now().isoformat(),
        "platform": "AlmaLinux"
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
            "os": "AlmaLinux",
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

    # UI
    mkdir -p ui
    cat > ui/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Laika Dynamics RAG System</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { 
            font-family: Arial, sans-serif; 
            margin: 0; 
            padding: 20px; 
            background: linear-gradient(135deg, #667eea, #764ba2); 
            min-height: 100vh; 
        }
        .container { 
            max-width: 1200px; 
            margin: 0 auto; 
            background: white; 
            padding: 40px; 
            border-radius: 15px; 
            box-shadow: 0 20px 40px rgba(0,0,0,0.1); 
        }
        h1 { 
            color: #2c3e50; 
            text-align: center; 
            margin-bottom: 30px; 
            font-size: 2.5rem; 
        }
        .status { 
            background: #27ae60; 
            color: white; 
            padding: 20px; 
            border-radius: 10px; 
            text-align: center; 
            margin: 20px 0; 
            font-size: 1.2rem; 
        }
        .grid { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr)); 
            gap: 20px; 
            margin: 30px 0; 
        }
        .card { 
            background: #f8f9fa; 
            padding: 25px; 
            border-radius: 10px; 
            border-left: 4px solid #3498db; 
        }
        .card h3 { 
            color: #2c3e50; 
            margin-bottom: 15px; 
        }
        .url { 
            background: #e9ecef; 
            padding: 12px; 
            border-radius: 5px; 
            margin: 8px 0; 
        }
        .url a { 
            color: #3498db; 
            text-decoration: none; 
            font-family: monospace; 
        }
        .url a:hover { 
            text-decoration: underline; 
        }
        #apiStatus { 
            padding: 10px 20px; 
            border-radius: 20px; 
            margin: 10px; 
            font-weight: bold; 
        }
        .online { 
            background: #27ae60; 
            color: white; 
        }
        .offline { 
            background: #e74c3c; 
            color: white; 
        }
        ul { 
            list-style: none; 
            padding: 0; 
        }
        li { 
            padding: 8px 0; 
            border-bottom: 1px solid #dee2e6; 
        }
        li:last-child { 
            border-bottom: none; 
        }
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
                <p>Complete RAG system for web contracting data analysis. Built on AlmaLinux 9 with Python 3.11, accessible globally.</p>
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
                    <p><strong>OS:</strong> ${data.system?.os || 'AlmaLinux'}</p>
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

    log "✅ All files created"
}

# Main installation
main() {
    header "🚀 LAIKA DYNAMICS - ALMALINUX INSTALL"
    
    info "VPS IP: $VPS_IP"
    info "Project: $PROJECT_DIR"
    
    quick_cleanup
    setup_almalinux
    setup_firewall
    create_project
    setup_python
    create_files
    
    header "✅ INSTALLATION COMPLETE!"
    
    info ""
    info "🎉 System ready! Run these commands:"
    info ""
    info "cd $PROJECT_DIR"
    info "./start.sh      # Start services"
    info "./stop.sh       # Stop services"
    info "./status.sh     # Check status"
    info "./logs.sh       # View logs"
    info ""
    info "🌍 Access URLs:"
    info "  🌐 Web: http://$VPS_IP:3000"
    info "  📡 API: http://$VPS_IP:8000"
    info ""
    info "🚀 Ready for deployment!"
}

main "$@" 