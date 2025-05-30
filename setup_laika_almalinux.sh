#!/bin/bash

# RAG Web Contracting Dataset Setup Script for AlmaLinux 9 VPS
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

# Display usage information
show_usage() {
    echo -e "${BLUE}Laika Dynamics RAG System - AlmaLinux 9${NC}"
    echo -e "${GREEN}Usage: $0 [COMMAND]${NC}"
    echo ""
    echo "Commands:"
    echo "  install     Full installation and setup (default)"
    echo "  start       Start the RAG system services"
    echo "  stop        Stop the RAG system services"
    echo "  status      Show system status"
    echo "  restart     Restart the RAG system services"
    echo "  logs        Show system logs"
    echo "  help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                # Full installation"
    echo "  $0 install        # Full installation"
    echo "  $0 start          # Start services"
    echo "  $0 stop           # Stop services"
    echo "  $0 status         # Check status"
    echo ""
}

# Check if project exists
check_project_exists() {
    if [ ! -d "$PROJECT_DIR" ]; then
        error "Project directory $PROJECT_DIR not found. Run '$0 install' first."
    fi
    cd "$PROJECT_DIR"
}

# Start the RAG system
start_system() {
    log "🚀 Starting Laika Dynamics RAG System..."
    check_project_exists
    
    if [ -f "./start_rag_system.sh" ]; then
        ./start_rag_system.sh
    else
        error "Start script not found. Run '$0 install' first."
    fi
}

# Stop the RAG system
stop_system() {
    log "🛑 Stopping Laika Dynamics RAG System..."
    check_project_exists
    
    if [ -f "./stop_rag_system.sh" ]; then
        ./stop_rag_system.sh
    else
        # Manual stop if script doesn't exist
        if [ -f api.pid ]; then
            kill $(cat api.pid) 2>/dev/null || true
            rm -f api.pid
            log "✅ API server stopped"
        fi
        
        if [ -f ui.pid ]; then
            kill $(cat ui.pid) 2>/dev/null || true
            rm -f ui.pid
            log "✅ Web interface stopped"
        fi
        
        log "🎉 System stopped successfully"
    fi
}

# Restart the RAG system
restart_system() {
    log "🔄 Restarting Laika Dynamics RAG System..."
    stop_system
    sleep 3
    start_system
}

# Show system status
show_status() {
    log "📊 Laika Dynamics RAG System Status"
    check_project_exists
    
    echo ""
    echo -e "${BLUE}=== Service Status ===${NC}"
    
    # Check API status
    if [ -f api.pid ] && kill -0 $(cat api.pid) 2>/dev/null; then
        echo -e "API Server: ${GREEN}Running${NC} (PID: $(cat api.pid))"
    else
        echo -e "API Server: ${RED}Stopped${NC}"
    fi
    
    # Check UI status
    if [ -f ui.pid ] && kill -0 $(cat ui.pid) 2>/dev/null; then
        echo -e "Web Interface: ${GREEN}Running${NC} (PID: $(cat ui.pid))"
    else
        echo -e "Web Interface: ${RED}Stopped${NC}"
    fi
    
    # Check Docker/Qdrant status
    if command -v docker &> /dev/null; then
        if docker ps | grep -q qdrant; then
            echo -e "Qdrant Vector DB: ${GREEN}Running${NC}"
        else
            echo -e "Qdrant Vector DB: ${RED}Stopped${NC}"
        fi
    else
        echo -e "Docker: ${YELLOW}Not installed${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}=== System Information ===${NC}"
    
    # Check firewall status
    if command -v firewall-cmd &> /dev/null; then
        if systemctl is-active firewalld &>/dev/null; then
            echo -e "Firewall: ${GREEN}Active${NC}"
        else
            echo -e "Firewall: ${RED}Inactive${NC}"
        fi
    fi
    
    # Check SELinux status
    if command -v getenforce &> /dev/null; then
        SELINUX_STATUS=$(getenforce)
        echo -e "SELinux: ${YELLOW}$SELINUX_STATUS${NC}"
    fi
    
    # Show access URLs
    echo ""
    echo -e "${BLUE}=== Access URLs ===${NC}"
    echo -e "🌐 Web Interface: ${GREEN}http://$VPS_IP:$UI_PORT${NC}"
    echo -e "📡 API Endpoint:  ${GREEN}http://$VPS_IP:$API_PORT${NC}"
    echo -e "📋 API Docs:      ${GREEN}http://$VPS_IP:$API_PORT/docs${NC}"
    echo -e "🐧 AlmaLinux Info: ${GREEN}http://$VPS_IP:$API_PORT/almalinux${NC}"
    
    # Test API connectivity
    echo ""
    echo -e "${BLUE}=== Connectivity Test ===${NC}"
    if curl -s --connect-timeout 3 "http://localhost:$API_PORT/health" &>/dev/null; then
        echo -e "API Health Check: ${GREEN}✅ Healthy${NC}"
    else
        echo -e "API Health Check: ${RED}❌ Failed${NC}"
    fi
}

# Show system logs
show_logs() {
    log "📝 Showing Laika Dynamics RAG System Logs..."
    check_project_exists
    
    echo -e "${BLUE}=== Recent API Logs ===${NC}"
    if [ -f "logs/api.log" ]; then
        tail -20 logs/api.log
    else
        echo "No API logs found"
    fi
    
    echo ""
    echo -e "${BLUE}=== Recent UI Logs ===${NC}"
    if [ -f "logs/ui.log" ]; then
        tail -20 logs/ui.log
    else
        echo "No UI logs found"
    fi
    
    echo ""
    echo -e "${BLUE}=== Recent Access Logs ===${NC}"
    if [ -f "logs/access.log" ]; then
        tail -10 logs/access.log
    else
        echo "No access logs found"
    fi
    
    echo ""
    echo -e "${BLUE}=== Recent Error Logs ===${NC}"
    if [ -f "logs/error.log" ]; then
        tail -10 logs/error.log
    else
        echo "No error logs found"
    fi
}

# Detect AlmaLinux
detect_almalinux() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" == "almalinux" ]]; then
            log "✅ Detected AlmaLinux $VERSION_ID"
            return 0
        else
            warn "This script is optimized for AlmaLinux 9, detected: $PRETTY_NAME"
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    else
        error "Cannot detect operating system"
    fi
}

# Check system requirements for AlmaLinux VPS
check_almalinux_requirements() {
    log "Checking AlmaLinux VPS system requirements..."
    
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
    
    # Update AlmaLinux packages
    log "Updating AlmaLinux packages..."
    sudo dnf update -y
    
    # Enable EPEL and CodeReady repos
    log "Enabling EPEL repository..."
    sudo dnf install -y epel-release
    
    log "Installing base packages for AlmaLinux..."
    sudo dnf install -y curl wget git gcc sqlite sqlite-devel python3 python3-pip python3-devel
    
    # Install Python 3.11 from AppStream
    log "Installing Python 3.11 from AppStream..."
    sudo dnf module enable python311 -y
    sudo dnf install -y python3.11 python3.11-pip python3.11-devel
}

# Configure firewalld for AlmaLinux
configure_almalinux_firewall() {
    log "Configuring firewalld for AlmaLinux VPS..."
    
    # Ensure firewalld is installed and running
    sudo dnf install -y firewalld
    sudo systemctl enable firewalld
    sudo systemctl start firewalld
    
    # Allow our application ports through firewalld
    log "Opening ports in firewalld..."
    sudo firewall-cmd --permanent --add-port=$API_PORT/tcp
    sudo firewall-cmd --permanent --add-port=$UI_PORT/tcp
    sudo firewall-cmd --permanent --add-port=$QDRANT_PORT/tcp
    
    # Allow HTTP and HTTPS for good measure
    sudo firewall-cmd --permanent --add-service=http
    sudo firewall-cmd --permanent --add-service=https
    
    # Reload firewall
    sudo firewall-cmd --reload
    
    # Show current configuration
    log "Current firewall configuration:"
    sudo firewall-cmd --list-all
    
    # Configure SELinux for network services
    if command -v getenforce &> /dev/null && [[ "$(getenforce)" == "Enforcing" ]]; then
        log "Configuring SELinux for network services..."
        sudo setsebool -P httpd_can_network_connect 1
        sudo setsebool -P httpd_can_network_relay 1
        
        # Allow custom ports
        sudo semanage port -a -t http_port_t -p tcp $API_PORT 2>/dev/null || true
        sudo semanage port -a -t http_port_t -p tcp $UI_PORT 2>/dev/null || true
        sudo semanage port -a -t http_port_t -p tcp $QDRANT_PORT 2>/dev/null || true
    fi
}

# Setup project directory
setup_project() {
    log "Setting up project directory: $PROJECT_DIR"
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    # Create directory structure
    mkdir -p data/synthetic data/knowledge configs scripts api ui logs
}

# Setup Python environment for AlmaLinux
setup_almalinux_python() {
    log "Setting up Python 3.11 virtual environment on AlmaLinux..."
    cd "$PROJECT_DIR"
    
    # Create virtual environment with Python 3.11
    python3.11 -m venv $VENV_NAME
    source $VENV_NAME/bin/activate
    
    # Upgrade pip
    python -m pip install --upgrade pip
    
    # Install core dependencies
    log "Installing Python dependencies..."
    pip install fastapi uvicorn python-dotenv pyyaml aiofiles httpx gunicorn
}

# Install Docker for AlmaLinux
install_docker_almalinux() {
    log "Installing Docker for AlmaLinux..."
    
    if ! command -v docker &> /dev/null; then
        # Remove any old Docker packages
        sudo dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine podman runc
        
        # Add Docker repository
        sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        
        # Install Docker
        sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
        # Start and enable Docker
        sudo systemctl start docker
        sudo systemctl enable docker
        
        # Add user to docker group
        sudo usermod -aG docker $USER
        
        log "Docker installed successfully for AlmaLinux"
    else
        log "Docker already installed"
        sudo systemctl start docker
    fi
}

# Create AlmaLinux-optimized project files
create_almalinux_files() {
    log "Creating AlmaLinux-optimized project files..."
    cd "$PROJECT_DIR"
    
    # Create systemd service file for the API
    cat > laika-api.service << 'EOF'
[Unit]
Description=Laika Dynamics RAG API
After=network.target

[Service]
Type=simple
User=USER_PLACEHOLDER
WorkingDirectory=PROJECT_DIR_PLACEHOLDER/api
Environment=PATH=PROJECT_DIR_PLACEHOLDER/laika-rag-env/bin
ExecStart=PROJECT_DIR_PLACEHOLDER/laika-rag-env/bin/gunicorn main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # Replace placeholders
    sed -i "s|USER_PLACEHOLDER|$USER|g" laika-api.service
    sed -i "s|PROJECT_DIR_PLACEHOLDER|$PROJECT_DIR|g" laika-api.service
    
    # Create startup script for AlmaLinux
    cat > start_rag_system.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "🚀 Starting Laika Dynamics RAG system on AlmaLinux 9..."

# Check if already running
if [ -f api.pid ] && kill -0 $(cat api.pid) 2>/dev/null; then
    echo "⚠️  API server is already running (PID: $(cat api.pid))"
else
    # Activate virtual environment
    source laika-rag-env/bin/activate

    # Start API server with gunicorn for production
    echo "🌐 Starting API server with gunicorn..."
    cd api && nohup gunicorn main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000 --access-logfile ../logs/access.log --error-logfile ../logs/error.log > ../logs/api.log 2>&1 &
    API_PID=$!
    echo $API_PID > ../api.pid
    cd ..
    echo "✅ API server started (PID: $API_PID)"
fi

# Check if UI already running
if [ -f ui.pid ] && kill -0 $(cat ui.pid) 2>/dev/null; then
    echo "⚠️  Web interface is already running (PID: $(cat ui.pid))"
else
    # Start web interface
    echo "🎨 Starting web interface..."
    cd ui && nohup python -m http.server 3000 --bind 0.0.0.0 > ../logs/ui.log 2>&1 &
    UI_PID=$!
    echo $UI_PID > ../ui.pid
    cd ..
    echo "✅ Web interface started (PID: $UI_PID)"
fi

echo ""
echo "✅ Laika Dynamics RAG System is LIVE on AlmaLinux!"
echo "🌐 Web Interface: http://194.238.17.65:3000"
echo "📡 API Endpoint:  http://194.238.17.65:8000"
echo "📋 System Info:   http://194.238.17.65:8000/system"
echo "📝 Logs: logs/api.log, logs/ui.log, logs/access.log, logs/error.log"
echo ""
echo "🔧 AlmaLinux Management:"
echo "  • Check status: ./setup_laika_almalinux.sh status"
echo "  • View logs: ./setup_laika_almalinux.sh logs"
echo "  • Stop system: ./setup_laika_almalinux.sh stop"
EOF

    chmod +x start_rag_system.sh
    
    # Create stop script
    cat > stop_rag_system.sh << 'EOF'
#!/bin/bash
echo "🛑 Stopping Laika Dynamics RAG System..."

# Stop API server
if [ -f api.pid ]; then
    if kill -0 $(cat api.pid) 2>/dev/null; then
        kill $(cat api.pid) 2>/dev/null
        echo "✅ API server stopped"
    else
        echo "⚠️  API server was not running"
    fi
    rm -f api.pid
else
    echo "⚠️  No API server PID file found"
fi

# Stop UI server
if [ -f ui.pid ]; then
    if kill -0 $(cat ui.pid) 2>/dev/null; then
        kill $(cat ui.pid) 2>/dev/null
        echo "✅ Web interface stopped"
    else
        echo "⚠️  Web interface was not running"
    fi
    rm -f ui.pid
else
    echo "⚠️  No UI server PID file found"
fi

echo "🎉 System stopped successfully"
EOF

    chmod +x stop_rag_system.sh
    
    # Create AlmaLinux-optimized API
    mkdir -p api
    cat > api/main.py << 'EOF'
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import platform
import os
import subprocess

app = FastAPI(
    title="Laika Dynamics RAG API", 
    version="1.0.0",
    description="RAG API optimized for AlmaLinux 9"
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
        "message": "Laika Dynamics RAG API running on AlmaLinux 9!", 
        "status": "active",
        "platform": "AlmaLinux 9",
        "python_version": platform.python_version(),
        "architecture": platform.machine()
    }

@app.get("/health")
async def health():
    return {
        "status": "healthy", 
        "version": "1.0.0",
        "platform": "almalinux",
        "services": {
            "api": "running",
            "firewalld": get_service_status("firewalld"),
            "docker": get_service_status("docker")
        }
    }

@app.get("/system")
async def system_info():
    try:
        # Get AlmaLinux version
        with open('/etc/os-release', 'r') as f:
            os_info = {}
            for line in f:
                if '=' in line:
                    key, value = line.strip().split('=', 1)
                    os_info[key] = value.strip('"')
    except:
        os_info = {"error": "Could not read OS info"}
    
    return {
        "hostname": platform.node(),
        "platform": platform.platform(),
        "processor": platform.processor(),
        "python_implementation": platform.python_implementation(),
        "python_version": platform.python_version(),
        "os_release": os_info,
        "architecture": platform.architecture(),
        "cpu_count": os.cpu_count()
    }

@app.get("/almalinux")
async def almalinux_info():
    """AlmaLinux-specific system information"""
    info = {
        "distribution": "AlmaLinux",
        "firewall": "firewalld",
        "package_manager": "dnf",
        "init_system": "systemd",
        "security": "SELinux"
    }
    
    # Check SELinux status
    try:
        result = subprocess.run(['getenforce'], capture_output=True, text=True)
        info["selinux_status"] = result.stdout.strip()
    except:
        info["selinux_status"] = "unknown"
    
    # Check firewall status
    try:
        result = subprocess.run(['firewall-cmd', '--state'], capture_output=True, text=True)
        info["firewall_status"] = result.stdout.strip()
    except:
        info["firewall_status"] = "unknown"
    
    return info

def get_service_status(service_name):
    """Check if a systemd service is running"""
    try:
        result = subprocess.run(['systemctl', 'is-active', service_name], 
                              capture_output=True, text=True)
        return result.stdout.strip()
    except:
        return "unknown"
EOF

    # Create AlmaLinux-optimized web UI
    mkdir -p ui
    cat > ui/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Laika Dynamics RAG - AlmaLinux 9</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%); 
            min-height: 100vh; 
            padding: 20px; 
        }
        .container { 
            max-width: 1000px; 
            margin: 0 auto; 
            background: white; 
            border-radius: 15px; 
            box-shadow: 0 20px 40px rgba(0,0,0,0.1); 
            overflow: hidden; 
        }
        .header { 
            background: linear-gradient(135deg, #c62d42 0%, #e74c3c 100%); 
            color: white; 
            padding: 30px; 
            text-align: center; 
        }
        .header h1 { font-size: 2.5em; margin-bottom: 10px; }
        .header p { opacity: 0.9; font-size: 1.1em; }
        .content { padding: 30px; }
        .status { 
            background: #27ae60; 
            color: white; 
            padding: 15px; 
            border-radius: 8px; 
            text-align: center; 
            margin: 20px 0; 
            font-weight: bold; 
            font-size: 1.1em; 
        }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin: 20px 0; }
        .card { 
            background: #f8f9fa; 
            padding: 20px; 
            border-radius: 10px; 
            border-left: 4px solid #e74c3c; 
        }
        .card h3 { color: #2c3e50; margin-bottom: 15px; }
        .almalinux-badge { 
            background: #e74c3c; 
            color: white; 
            padding: 8px 15px; 
            border-radius: 20px; 
            display: inline-block; 
            font-weight: bold; 
            margin: 10px 5px; 
        }
        .url-card { 
            background: #3498db; 
            color: white; 
            padding: 20px; 
            border-radius: 10px; 
            margin: 20px 0; 
        }
        .url-card a { color: white; text-decoration: none; font-weight: bold; }
        .url-card a:hover { text-decoration: underline; }
        .code { 
            background: #2c3e50; 
            color: #ecf0f1; 
            padding: 15px; 
            border-radius: 8px; 
            font-family: 'Courier New', monospace; 
            margin: 15px 0; 
            overflow-x: auto; 
        }
        .feature-list { list-style: none; }
        .feature-list li { 
            padding: 8px 0; 
            border-bottom: 1px solid #ecf0f1; 
        }
        .feature-list li:before { 
            content: "✓ "; 
            color: #27ae60; 
            font-weight: bold; 
        }
        .system-info { 
            background: #34495e; 
            color: white; 
            padding: 20px; 
            border-radius: 10px; 
            margin: 20px 0; 
        }
        .spinner { 
            border: 3px solid #f3f3f3; 
            border-top: 3px solid #e74c3c; 
            border-radius: 50%; 
            width: 20px; 
            height: 20px; 
            animation: spin 1s linear infinite; 
            display: inline-block; 
            margin-right: 10px; 
        }
        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Laika Dynamics RAG System</h1>
            <p>Enterprise AI Platform on AlmaLinux 9</p>
            <div style="margin-top: 15px;">
                <span class="almalinux-badge">AlmaLinux 9</span>
                <span class="almalinux-badge">Enterprise Ready</span>
                <span class="almalinux-badge">Global Access</span>
            </div>
        </div>
        
        <div class="content">
            <div class="status">✅ System Online & Operational on AlmaLinux 9</div>
            
            <div class="url-card">
                <h3>🌍 Global Access Points</h3>
                <p><strong>Web Interface:</strong> <a href="http://194.238.17.65:3000" target="_blank">http://194.238.17.65:3000</a></p>
                <p><strong>API Endpoint:</strong> <a href="http://194.238.17.65:8000" target="_blank">http://194.238.17.65:8000</a></p>
                <p><strong>API Documentation:</strong> <a href="http://194.238.17.65:8000/docs" target="_blank">http://194.238.17.65:8000/docs</a></p>
                <p><strong>AlmaLinux Info:</strong> <a href="http://194.238.17.65:8000/almalinux" target="_blank">http://194.238.17.65:8000/almalinux</a></p>
            </div>
            
            <div class="grid">
                <div class="card">
                    <h3>🐧 AlmaLinux 9 Features</h3>
                    <ul class="feature-list">
                        <li><strong>firewalld</strong> - Enterprise firewall</li>
                        <li><strong>SELinux</strong> - Enhanced security</li>
                        <li><strong>dnf</strong> - Modern package manager</li>
                        <li><strong>systemd</strong> - Service management</li>
                        <li><strong>Python 3.11</strong> - Latest runtime</li>
                        <li><strong>RHEL Compatible</strong> - Enterprise grade</li>
                    </ul>
                </div>
                
                <div class="card">
                    <h3>🤖 RAG System Components</h3>
                    <ul class="feature-list">
                        <li>FastAPI backend with Gunicorn</li>
                        <li>Production-ready deployment</li>
                        <li>CORS enabled for global access</li>
                        <li>Comprehensive logging</li>
                        <li>Health monitoring endpoints</li>
                        <li>System information APIs</li>
                    </ul>
                </div>
            </div>
            
            <div class="card">
                <h3>🛠️ AlmaLinux Management Commands</h3>
                <div class="code">
# Start the RAG system<br>
./setup_laika_almalinux.sh start<br><br>
# Stop the system<br>
./setup_laika_almalinux.sh stop<br><br>
# Check system status<br>
./setup_laika_almalinux.sh status<br><br>
# View logs<br>
./setup_laika_almalinux.sh logs<br><br>
# Restart system<br>
./setup_laika_almalinux.sh restart<br><br>
# Check firewall status<br>
sudo firewall-cmd --list-all<br><br>
# Check SELinux status<br>
sudo getenforce
                </div>
            </div>
            
            <div class="system-info">
                <h3>📊 Live System Status</h3>
                <div id="systemStatus">
                    <div class="spinner"></div>Loading system information...
                </div>
            </div>
            
            <div class="card">
                <h3>🎯 Perfect for Enterprise Demos</h3>
                <p>This system showcases a complete RAG deployment optimized specifically for AlmaLinux 9, demonstrating enterprise-grade Linux server management, security configurations, and global accessibility. Ideal for showcasing modern AI infrastructure on RHEL-compatible systems.</p>
            </div>
        </div>
    </div>

    <script>
        async function loadSystemInfo() {
            try {
                const [healthResponse, systemResponse, almaResponse] = await Promise.all([
                    fetch('http://194.238.17.65:8000/health'),
                    fetch('http://194.238.17.65:8000/system'),
                    fetch('http://194.238.17.65:8000/almalinux')
                ]);
                
                const health = await healthResponse.json();
                const system = await systemResponse.json();
                const alma = await almaResponse.json();
                
                document.getElementById('systemStatus').innerHTML = `
                    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px;">
                        <div>
                            <strong>Platform:</strong><br>
                            ${system.os_release?.PRETTY_NAME || 'AlmaLinux 9'}
                        </div>
                        <div>
                            <strong>Python:</strong><br>
                            ${system.python_version}
                        </div>
                        <div>
                            <strong>SELinux:</strong><br>
                            ${alma.selinux_status || 'Unknown'}
                        </div>
                        <div>
                            <strong>Firewall:</strong><br>
                            ${alma.firewall_status || 'Unknown'}
                        </div>
                        <div>
                            <strong>API Status:</strong><br>
                            ${health.status}
                        </div>
                        <div>
                            <strong>CPU Count:</strong><br>
                            ${system.cpu_count} cores
                        </div>
                    </div>
                `;
            } catch (error) {
                document.getElementById('systemStatus').innerHTML = 
                    '<span style="color: #e74c3c;">⚠️ Could not connect to API. System may still be starting up.</span>';
            }
        }
        
        // Load system info on page load and refresh every 30 seconds
        loadSystemInfo();
        setInterval(loadSystemInfo, 30000);
    </script>
</body>
</html>
EOF

    log "AlmaLinux-optimized project files created successfully!"
}

# Full installation process
install_system() {
    log "🚀 Starting Laika Dynamics VPS Setup for AlmaLinux 9"
    log "Target VPS: $VPS_IP"
    log "Project directory: $PROJECT_DIR"
    
    # Detect and verify AlmaLinux
    detect_almalinux
    
    # Check VPS requirements and setup
    check_almalinux_requirements
    configure_almalinux_firewall
    
    # Setup project structure
    setup_project
    setup_almalinux_python
    install_docker_almalinux
    create_almalinux_files
    
    log "✅ Laika Dynamics VPS setup complete for AlmaLinux 9!"
    log ""
    log "🐧 ALMALINUX 9 DEPLOYMENT READY!"
    log ""
    log "Next steps:"
    log "1. Start services: $0 start"
    log "2. Check status: $0 status"
    log "3. View logs: $0 logs"
    log ""
    log "Access URLs:"
    log "   🌐 Web UI: http://$VPS_IP:$UI_PORT"
    log "   📡 API: http://$VPS_IP:$API_PORT"
    log "   📋 AlmaLinux Info: http://$VPS_IP:$API_PORT/almalinux"
    log ""
    log "🔧 AlmaLinux 9 Optimizations Applied:"
    log "✓ firewalld configured for public access"
    log "✓ SELinux policies configured for web services"
    log "✓ Python 3.11 installed from AppStream"
    log "✓ dnf package management used"
    log "✓ systemd service files created"
    log "✓ Production-ready Gunicorn deployment"
    log "✓ Comprehensive logging setup"
    log ""
    log "🎯 Perfect for enterprise AI demonstrations!"
    log "💡 This setup showcases modern RHEL-compatible enterprise Linux!"
}

# Main execution
main() {
    # Parse command line arguments
    case "${1:-install}" in
        "install")
            install_system
            ;;
        "start")
            start_system
            ;;
        "stop")
            stop_system
            ;;
        "restart")
            restart_system
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            echo -e "${RED}Unknown command: $1${NC}"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@" 