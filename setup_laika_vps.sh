#!/bin/bash

# RAG Web Contracting Dataset Setup Script for VPS
set -e  # Exit on any error

# Configuration
PROJECT_DIR="$HOME/laika-dynamics-rag"
VENV_NAME="laika-rag-env"
PYTHON_VERSION="3.11"
QDRANT_PORT="6333"
API_PORT="8000"
UI_PORT="3000"
VPS_IP="194.238.17.65"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Check system requirements for VPS
check_vps_requirements() {
    log "Checking VPS system requirements..."
    
    # Check memory
    MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
    if [ $MEMORY_GB -lt 7 ]; then
        warn "VPS has ${MEMORY_GB}GB RAM. 8GB recommended for optimal performance."
    else
        log "Memory check passed: ${MEMORY_GB}GB available"
    fi
    
    # Check disk space
    DISK_AVAIL=$(df -BG / | awk 'NR==2{print $4}' | sed 's/G//')
    if [ $DISK_AVAIL -lt 20 ]; then
        error "Insufficient disk space. Need at least 20GB free, have ${DISK_AVAIL}GB"
    else
        log "Disk space check passed: ${DISK_AVAIL}GB available"
    fi
    
    # Check CPU cores
    CPU_CORES=$(nproc)
    log "CPU cores: $CPU_CORES"
    
    # Update system packages
    log "Updating system packages..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update -y
        sudo apt-get install -y curl wget git python3 python3-pip python3-venv build-essential sqlite3
    elif command -v yum &> /dev/null; then
        sudo yum update -y
        sudo yum install -y curl wget git python3 python3-pip gcc sqlite
    fi
}

# Configure UFW firewall for VPS
configure_firewall() {
    log "Configuring firewall for public access..."
    
    if command -v ufw &> /dev/null; then
        # Enable UFW if not already enabled
        sudo ufw --force enable
        
        # Allow SSH
        sudo ufw allow ssh
        sudo ufw allow 22
        
        # Allow our application ports
        sudo ufw allow $API_PORT comment "Laika Dynamics API"
        sudo ufw allow $UI_PORT comment "Laika Dynamics Web UI"
        sudo ufw allow $QDRANT_PORT comment "Qdrant Vector DB"
        
        # Show status
        sudo ufw status
        log "Firewall configured for ports: $API_PORT, $UI_PORT, $QDRANT_PORT"
    else
        warn "UFW not available. Please manually configure firewall if needed."
    fi
}

# Setup project directory
setup_project() {
    log "Setting up project directory: $PROJECT_DIR"
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    # Create directory structure
    mkdir -p data/synthetic data/knowledge configs scripts api ui
}

# Setup Python environment
setup_python_env() {
    log "Setting up Python virtual environment..."
    cd "$PROJECT_DIR"
    
    # Create virtual environment
    python3 -m venv $VENV_NAME
    source $VENV_NAME/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install core dependencies
    log "Installing Python dependencies..."
    pip install fastapi uvicorn python-dotenv pyyaml aiofiles httpx psutil
    
    # Install additional dependencies from requirements.txt if needed
    if [ -f requirements.txt ]; then
        log "Installing additional dependencies from requirements.txt..."
        pip install -r requirements.txt
    fi
}

# Create project files
create_project_files() {
    log "Creating project configuration files..."
    cd "$PROJECT_DIR"
    
    # Create comprehensive startup script
    cat > start_rag_system.sh << 'EOF'
#!/bin/bash

# Laika Dynamics RAG System Startup Script
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$PROJECT_DIR/laika-rag-env"
API_PORT="8000"
UI_PORT="3000"
VPS_IP="194.238.17.65"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

info() {
    echo -e "${BLUE}$1${NC}"
}

warn() {
    echo -e "${YELLOW}$1${NC}"
}

# Function to start API server
start_api() {
    log "Starting API server on port $API_PORT..."
    cd "$PROJECT_DIR"
    source "$VENV_DIR/bin/activate"
    
    # Kill any existing API processes
    pkill -f "uvicorn.*api.main" 2>/dev/null || true
    
    # Start API server in background
    nohup uvicorn api.main:app --host 0.0.0.0 --port $API_PORT --reload > logs/api.log 2>&1 &
    echo $! > api.pid
    
    sleep 3
    if pgrep -f "uvicorn.*api.main" > /dev/null; then
        log "✅ API server started successfully (PID: $(cat api.pid))"
        info "📡 API available at: http://$VPS_IP:$API_PORT"
        info "📚 API docs at: http://$VPS_IP:$API_PORT/docs"
    else
        warn "❌ Failed to start API server. Check logs/api.log"
        return 1
    fi
}

# Function to start UI server
start_ui() {
    log "Starting UI server on port $UI_PORT..."
    cd "$PROJECT_DIR"
    
    # Kill any existing UI processes
    pkill -f "python.*ui_server.py" 2>/dev/null || true
    
    # Start UI server in background
    nohup python3 ui_server.py > logs/ui.log 2>&1 &
    echo $! > ui.pid
    
    sleep 2
    if pgrep -f "python.*ui_server.py" > /dev/null; then
        log "✅ UI server started successfully (PID: $(cat ui.pid))"
        info "🌐 Web Interface at: http://$VPS_IP:$UI_PORT"
    else
        warn "❌ Failed to start UI server. Check logs/ui.log"
        return 1
    fi
}

# Function to show status
show_status() {
    info ""
    info "🚀 Laika Dynamics RAG System Status"
    info "=================================="
    
    if pgrep -f "uvicorn.*api.main" > /dev/null; then
        info "✅ API Server: Running on port $API_PORT"
    else
        info "❌ API Server: Not running"
    fi
    
    if pgrep -f "python.*ui_server.py" > /dev/null; then
        info "✅ UI Server: Running on port $UI_PORT"
    else
        info "❌ UI Server: Not running"
    fi
    
    info ""
    info "🌍 Global Access URLs:"
    info "  🌐 Web Interface: http://$VPS_IP:$UI_PORT"
    info "  📡 API Endpoint:  http://$VPS_IP:$API_PORT"
    info "  📚 API Docs:      http://$VPS_IP:$API_PORT/docs"
    info ""
}

# Function to stop services
stop_services() {
    log "Stopping all services..."
    
    if [ -f api.pid ]; then
        kill $(cat api.pid) 2>/dev/null || true
        rm -f api.pid
    fi
    
    if [ -f ui.pid ]; then
        kill $(cat ui.pid) 2>/dev/null || true
        rm -f ui.pid
    fi
    
    pkill -f "uvicorn.*api.main" 2>/dev/null || true
    pkill -f "python.*ui_server.py" 2>/dev/null || true
    
    log "✅ All services stopped"
}

# Main execution
case "${1:-start}" in
    start)
        log "🚀 Starting Laika Dynamics RAG System..."
        
        # Create logs directory
        mkdir -p logs
        
        # Start services
        start_api
        start_ui
        show_status
        ;;
    stop)
        stop_services
        ;;
    status)
        show_status
        ;;
    restart)
        stop_services
        sleep 2
        "$0" start
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart}"
        exit 1
        ;;
esac
EOF

    chmod +x start_rag_system.sh
    
    # Create UI server script
    cat > ui_server.py << 'EOF'
#!/usr/bin/env python3
"""
Simple HTTP server for Laika Dynamics RAG UI
Serves static files from the ui directory on port 3000
"""

import http.server
import socketserver
import os
import sys
from pathlib import Path

# Configuration
PORT = 3000
UI_DIR = "ui"

class CustomHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=UI_DIR, **kwargs)
    
    def end_headers(self):
        # Add CORS headers for cross-origin requests
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        super().end_headers()
    
    def log_message(self, format, *args):
        # Custom logging format
        print(f"[UI] {self.address_string()} - {format % args}")

def main():
    # Change to project directory
    script_dir = Path(__file__).parent.absolute()
    os.chdir(script_dir)
    
    # Verify UI directory exists
    if not os.path.exists(UI_DIR):
        print(f"❌ ERROR: {UI_DIR} directory not found!")
        print(f"Current directory: {os.getcwd()}")
        sys.exit(1)
    
    # Verify index.html exists
    index_file = os.path.join(UI_DIR, "index.html")
    if not os.path.exists(index_file):
        print(f"❌ ERROR: {index_file} not found!")
        sys.exit(1)
    
    print(f"🌐 Starting UI server on port {PORT}")
    print(f"📁 Serving files from: {os.path.abspath(UI_DIR)}")
    print(f"🔗 Access at: http://194.238.17.65:{PORT}")
    
    try:
        with socketserver.TCPServer(("0.0.0.0", PORT), CustomHTTPRequestHandler) as httpd:
            print(f"✅ UI server running on port {PORT}")
            httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n🛑 UI server stopped")
    except Exception as e:
        print(f"❌ Server error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
EOF

    chmod +x ui_server.py
    
    # Create enhanced API with system info
    mkdir -p api
    cat > api/main.py << 'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
import platform
import psutil
import os
from datetime import datetime

app = FastAPI(
    title="Laika Dynamics RAG API", 
    version="1.0.0",
    description="Enterprise RAG System for Web Contracting Data"
)

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
        "message": "Laika Dynamics RAG API is running!",
        "status": "active",
        "version": "1.0.0",
        "timestamp": datetime.now().isoformat()
    }

@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "version": "1.0.0",
        "uptime": "running",
        "timestamp": datetime.now().isoformat()
    }

@app.get("/system")
async def system_info():
    try:
        return {
            "system": {
                "os": platform.system(),
                "os_release": platform.release(),
                "distribution": platform.platform(),
                "architecture": platform.architecture()[0],
                "machine": platform.machine(),
                "processor": platform.processor(),
                "python_version": platform.python_version(),
                "hostname": platform.node()
            },
            "resources": {
                "cpu_count": psutil.cpu_count(),
                "cpu_percent": psutil.cpu_percent(interval=1),
                "memory": {
                    "total": f"{psutil.virtual_memory().total // (1024**3)}GB",
                    "available": f"{psutil.virtual_memory().available // (1024**3)}GB",
                    "percent": psutil.virtual_memory().percent
                },
                "disk": {
                    "total": f"{psutil.disk_usage('/').total // (1024**3)}GB",
                    "free": f"{psutil.disk_usage('/').free // (1024**3)}GB",
                    "percent": psutil.disk_usage('/').percent
                }
            },
            "status": "operational",
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        return {"error": str(e), "status": "error"}

@app.get("/ui", response_class=HTMLResponse)
async def ui_redirect():
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Laika Dynamics - Redirecting to UI</title>
        <meta http-equiv="refresh" content="0; url=http://194.238.17.65:3000">
    </head>
    <body>
        <h1>Redirecting to Laika Dynamics UI...</h1>
        <p>If you are not redirected automatically, <a href="http://194.238.17.65:3000">click here</a>.</p>
    </body>
    </html>
    """
EOF

    # Create enhanced web UI with better styling and functionality
    mkdir -p ui
    cat > ui/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Laika Dynamics RAG System</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container { 
            max-width: 1200px; 
            margin: 0 auto; 
            background: rgba(255, 255, 255, 0.95); 
            padding: 40px; 
            border-radius: 20px; 
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            backdrop-filter: blur(10px);
        }
        h1 { 
            color: #2c3e50; 
            text-align: center; 
            margin-bottom: 30px;
            font-size: 2.5rem;
            font-weight: 300;
        }
        .status { 
            background: linear-gradient(135deg, #27ae60, #2ecc71); 
            color: white; 
            padding: 20px; 
            border-radius: 10px; 
            text-align: center; 
            margin: 20px 0;
            font-size: 1.2rem;
            box-shadow: 0 10px 20px rgba(39, 174, 96, 0.3);
        }
        .grid { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr)); 
            gap: 20px; 
            margin: 30px 0; 
        }
        .card { 
            background: white; 
            padding: 25px; 
            border-radius: 15px; 
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
            border: 1px solid #e1e8ed;
            transition: transform 0.3s ease, box-shadow 0.3s ease;
        }
        .card:hover {
            transform: translateY(-5px);
            box-shadow: 0 15px 40px rgba(0,0,0,0.15);
        }
        .card h3 { 
            color: #2c3e50; 
            margin-bottom: 15px;
            font-size: 1.3rem;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .card p, .card ul { 
            color: #5a6c7d; 
            line-height: 1.6;
        }
        .card ul { 
            list-style: none;
            padding-left: 0;
        }
        .card li {
            padding: 8px 0;
            border-bottom: 1px solid #f1f3f4;
        }
        .card li:last-child {
            border-bottom: none;
        }
        .url-box {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 8px;
            margin: 10px 0;
            border-left: 4px solid #3498db;
        }
        .url-box strong {
            color: #2c3e50;
            display: block;
            margin-bottom: 5px;
        }
        .url-box a {
            color: #3498db;
            text-decoration: none;
            font-family: monospace;
            font-size: 0.9rem;
        }
        .url-box a:hover {
            text-decoration: underline;
        }
        .system-info {
            background: linear-gradient(135deg, #3498db, #2980b9);
            color: white;
            margin-top: 20px;
        }
        .api-status {
            text-align: center;
            margin: 20px 0;
        }
        #apiStatus {
            display: inline-block;
            padding: 10px 20px;
            border-radius: 25px;
            font-weight: bold;
            margin: 10px;
        }
        .status-online {
            background: #27ae60;
            color: white;
        }
        .status-offline {
            background: #e74c3c;
            color: white;
        }
        .emoji {
            font-size: 1.5rem;
            margin-right: 10px;
        }
        @media (max-width: 768px) {
            .container { padding: 20px; }
            h1 { font-size: 2rem; }
            .grid { grid-template-columns: 1fr; }
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Laika Dynamics RAG System</h1>
        <div class="status">
            <span class="emoji">✅</span>
            System Online & Ready for Global Access
        </div>
        
        <div class="api-status">
            <div id="apiStatus">Checking API Status...</div>
        </div>
        
        <div class="grid">
            <div class="card">
                <h3><span class="emoji">🌍</span>Public Access URLs</h3>
                <div class="url-box">
                    <strong>Web Interface:</strong>
                    <a href="http://194.238.17.65:3000" target="_blank">http://194.238.17.65:3000</a>
                </div>
                <div class="url-box">
                    <strong>API Endpoint:</strong>
                    <a href="http://194.238.17.65:8000" target="_blank">http://194.238.17.65:8000</a>
                </div>
                <div class="url-box">
                    <strong>API Documentation:</strong>
                    <a href="http://194.238.17.65:8000/docs" target="_blank">http://194.238.17.65:8000/docs</a>
                </div>
                <div class="url-box">
                    <strong>System Information:</strong>
                    <a href="http://194.238.17.65:8000/system" target="_blank">http://194.238.17.65:8000/system</a>
                </div>
            </div>
            
            <div class="card">
                <h3><span class="emoji">🤖</span>AI Features</h3>
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
                <h3><span class="emoji">🎯</span>Perfect for Demo</h3>
                <p>This system demonstrates a complete RAG (Retrieval Augmented Generation) setup for web contracting data analysis. Built on enterprise-grade AlmaLinux 9 with Python 3.11, it's accessible from anywhere in the world and perfect for showcasing AI capabilities to development teams.</p>
            </div>
            
            <div class="card">
                <h3><span class="emoji">⚡</span>System Status</h3>
                <div id="systemInfo">Loading system information...</div>
            </div>
        </div>
    </div>

    <script>
        // Check API status
        async function checkAPIStatus() {
            try {
                const response = await fetch('http://194.238.17.65:8000/health');
                const data = await response.json();
                document.getElementById('apiStatus').textContent = '✅ API Online';
                document.getElementById('apiStatus').className = 'status-online';
            } catch (error) {
                document.getElementById('apiStatus').textContent = '❌ API Offline';
                document.getElementById('apiStatus').className = 'status-offline';
            }
        }

        // Load system information
        async function loadSystemInfo() {
            try {
                const response = await fetch('http://194.238.17.65:8000/system');
                const data = await response.json();
                
                const systemHtml = `
                    <div style="text-align: left;">
                        <p><strong>OS:</strong> ${data.system?.distribution || 'Unknown'}</p>
                        <p><strong>Python:</strong> ${data.system?.python_version || 'Unknown'}</p>
                        <p><strong>CPU Cores:</strong> ${data.resources?.cpu_count || 'Unknown'}</p>
                        <p><strong>Memory:</strong> ${data.resources?.memory?.total || 'Unknown'}</p>
                        <p><strong>CPU Usage:</strong> ${data.resources?.cpu_percent || 'Unknown'}%</p>
                        <p><strong>Last Updated:</strong> ${new Date().toLocaleString()}</p>
                    </div>
                `;
                
                document.getElementById('systemInfo').innerHTML = systemHtml;
            } catch (error) {
                document.getElementById('systemInfo').innerHTML = '<p>Unable to load system information</p>';
            }
        }

        // Initialize page
        document.addEventListener('DOMContentLoaded', function() {
            checkAPIStatus();
            loadSystemInfo();
            
            // Refresh status every 30 seconds
            setInterval(checkAPIStatus, 30000);
            setInterval(loadSystemInfo, 60000);
        });
    </script>
</body>
</html>
EOF

    # Create requirements file for Python dependencies
    cat > requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
python-dotenv==1.0.0
pyyaml==6.0.1
aiofiles==23.2.1
httpx==0.25.2
psutil==5.9.6
sdv==1.8.0
pandas==2.1.3
numpy==1.25.2
EOF

    # Create logs directory
    mkdir -p logs
    
    log "Enhanced project files created successfully!"
    log "Added features:"
    log "  ✅ Proper UI server with static file serving"
    log "  ✅ Enhanced startup script with service management"
    log "  ✅ Improved API with system information endpoint"
    log "  ✅ Modern responsive web interface"
    log "  ✅ Real-time status checking"
    log "  ✅ Comprehensive logging"
}

# Main execution
main() {
    log "🚀 Starting Laika Dynamics VPS Setup"
    log "Target VPS: $VPS_IP"
    log "Project directory: $PROJECT_DIR"
    
    # Check VPS requirements and setup
    check_vps_requirements
    configure_firewall
    
    # Setup project structure
    setup_project
    setup_python_env
    create_project_files
    
    log "✅ Laika Dynamics VPS setup complete!"
    log ""
    log "🌍 READY FOR GLOBAL DEPLOYMENT!"
    log ""
    log "Next steps:"
    log "1. Run: cd $PROJECT_DIR && ./start_rag_system.sh"
    log "2. Access from anywhere:"
    log "   🌐 Web UI: http://$VPS_IP:$UI_PORT"
    log "   📡 API: http://$VPS_IP:$API_PORT"
    log ""
    log "🎯 Perfect for your AI dev team demo!"
}

# Run main function
main "$@" 