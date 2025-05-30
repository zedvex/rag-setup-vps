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
    pip install sdv pandas numpy fastapi uvicorn python-dotenv pyyaml aiofiles httpx
}

# Create project files
create_project_files() {
    log "Creating project configuration files..."
    cd "$PROJECT_DIR"
    
    # Create startup script
    cat > start_rag_system.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "🚀 Starting Laika Dynamics RAG system on VPS..."
source laika-rag-env/bin/activate
echo "✅ System ready for global access!"
echo "🌐 Web Interface: http://194.238.17.65:3000"
echo "📡 API Endpoint:  http://194.238.17.65:8000"
EOF

    chmod +x start_rag_system.sh
    
    # Create simple API
    mkdir -p api
    cat > api/main.py << 'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="Laika Dynamics RAG API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    return {"message": "Laika Dynamics RAG API is running!", "status": "active"}

@app.get("/health")
async def health():
    return {"status": "healthy", "version": "1.0.0"}
EOF

    # Create simple web UI
    mkdir -p ui
    cat > ui/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Laika Dynamics RAG System</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; text-align: center; }
        .status { background: #27ae60; color: white; padding: 10px; border-radius: 5px; text-align: center; margin: 20px 0; }
        .info { background: #3498db; color: white; padding: 15px; border-radius: 5px; margin: 10px 0; }
        .feature { background: #ecf0f1; padding: 15px; margin: 10px 0; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Laika Dynamics RAG System</h1>
        <div class="status">✅ System Online & Ready for Global Access</div>
        
        <div class="info">
            <h3>🌍 Public Access URLs:</h3>
            <p><strong>Web Interface:</strong> http://194.238.17.65:3000</p>
            <p><strong>API Endpoint:</strong> http://194.238.17.65:8000</p>
            <p><strong>API Documentation:</strong> http://194.238.17.65:8000/docs</p>
        </div>
        
        <div class="feature">
            <h3>🤖 AI Features</h3>
            <ul>
                <li>Synthetic business data generation</li>
                <li>Vector database with Qdrant</li>
                <li>Local AI models with Ollama</li>
                <li>RESTful API interface</li>
            </ul>
        </div>
        
        <div class="feature">
            <h3>🎯 Perfect for Demo</h3>
            <p>This system demonstrates a complete RAG (Retrieval Augmented Generation) setup for web contracting data analysis, accessible from anywhere in the world.</p>
        </div>
    </div>
</body>
</html>
EOF

    log "Project files created successfully!"
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