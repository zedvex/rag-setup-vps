#!/bin/bash

# Enhanced Laika Dynamics RAG System Deployment
# Deploys the new system with CTGAN, OpenAI integration, and advanced UI

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Configuration
PROJECT_DIR="$(pwd)"
API_PORT="8000"
UI_PORT="3000"
VPS_IP="194.238.17.65"

log "🚀 Deploying Enhanced Laika Dynamics RAG System"
log "Project directory: $PROJECT_DIR"

# Stop any existing services
log "Stopping existing services..."
pkill -f "uvicorn.*api.main" 2>/dev/null || true
pkill -f "python.*ui_server.py" 2>/dev/null || true
pkill -f "gunicorn" 2>/dev/null || true
fuser -k ${API_PORT}/tcp 2>/dev/null || true
fuser -k ${UI_PORT}/tcp 2>/dev/null || true

# Install system dependencies for AlmaLinux
log "Installing system dependencies..."
sudo dnf update -y
sudo dnf install -y python3 python3-pip python3-devel gcc gcc-c++ git curl wget
sudo dnf install -y sqlite sqlite-devel
sudo dnf groupinstall -y "Development Tools"

# Create virtual environment
log "Setting up Python virtual environment..."
python3 -m venv laika-rag-env
source laika-rag-env/bin/activate

# Upgrade pip
pip install --upgrade pip

# Install Python dependencies
log "Installing Python dependencies..."
pip install -r requirements.txt

# Create necessary directories
log "Creating project directories..."
mkdir -p data logs configs

# Initialize database
log "Initializing database..."
python3 -c "
import sys
sys.path.append('.')
from api.models import create_tables
create_tables()
print('✅ Database tables created')
"

# Create startup scripts
log "Creating startup scripts..."

# Enhanced startup script
cat > start.sh << 'EOF'
#!/bin/bash
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

info() {
    echo -e "${BLUE}$1${NC}"
}

# Kill existing processes
pkill -f "uvicorn.*api.main" 2>/dev/null || true
pkill -f "python.*ui_server.py" 2>/dev/null || true
fuser -k 8000/tcp 2>/dev/null || true
fuser -k 3000/tcp 2>/dev/null || true

# Activate virtual environment
source laika-rag-env/bin/activate

# Create logs directory
mkdir -p logs

# Start API server
log "Starting enhanced API server..."
nohup python3 -m uvicorn api.main:app --host 0.0.0.0 --port 8000 --reload > logs/api.log 2>&1 &
echo $! > api.pid

# Start UI server
log "Starting enhanced UI server..."
nohup python3 ui_server.py > logs/ui.log 2>&1 &
echo $! > ui.pid

sleep 3

# Check if services are running
if pgrep -f "uvicorn.*api.main" > /dev/null; then
    log "✅ Enhanced API server started successfully"
    info "📡 API available at: http://194.238.17.65:8000"
    info "📚 API docs at: http://194.238.17.65:8000/docs"
else
    echo "❌ Failed to start API server. Check logs/api.log"
fi

if pgrep -f "python.*ui_server.py" > /dev/null; then
    log "✅ Enhanced UI server started successfully"
    info "🌐 Web Interface at: http://194.238.17.65:3000"
else
    echo "❌ Failed to start UI server. Check logs/ui.log"
fi

echo ""
info "🎉 Enhanced Laika Dynamics RAG System Ready!"
info "Features:"
info "  ✨ CTGAN Synthetic Data Generation"
info "  🤖 OpenAI GPT Integration"
info "  🔍 Vector Database with Qdrant"
info "  📊 Real-time Analytics Dashboard"
info "  🎨 Modern Responsive UI"
echo ""
EOF

chmod +x start.sh

# Stop script
cat > stop.sh << 'EOF'
#!/bin/bash

echo "🛑 Stopping Laika Dynamics RAG System..."

# Stop services
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
fuser -k 8000/tcp 2>/dev/null || true
fuser -k 3000/tcp 2>/dev/null || true

echo "✅ All services stopped"
EOF

chmod +x stop.sh

# Status script
cat > status.sh << 'EOF'
#!/bin/bash

echo "📊 Laika Dynamics RAG System Status"
echo "=================================="

if pgrep -f "uvicorn.*api.main" > /dev/null; then
    echo "✅ API Server: Running on port 8000"
else
    echo "❌ API Server: Not running"
fi

if pgrep -f "python.*ui_server.py" > /dev/null; then
    echo "✅ UI Server: Running on port 3000"
else
    echo "❌ UI Server: Not running"
fi

echo ""
echo "🌍 Access URLs:"
echo "  🌐 Web Interface: http://194.238.17.65:3000"
echo "  📡 API Endpoint:  http://194.238.17.65:8000"
echo "  📚 API Docs:      http://194.238.17.65:8000/docs"
echo ""
EOF

chmod +x status.sh

# Logs script
cat > logs.sh << 'EOF'
#!/bin/bash

case "${1:-api}" in
    api)
        echo "📡 API Server Logs (last 50 lines):"
        echo "=================================="
        tail -n 50 logs/api.log 2>/dev/null || echo "No API logs found"
        ;;
    ui)
        echo "🌐 UI Server Logs (last 50 lines):"
        echo "================================="
        tail -n 50 logs/ui.log 2>/dev/null || echo "No UI logs found"
        ;;
    both|all)
        echo "📡 API Server Logs:"
        echo "=================="
        tail -n 25 logs/api.log 2>/dev/null || echo "No API logs found"
        echo ""
        echo "🌐 UI Server Logs:"
        echo "=================="
        tail -n 25 logs/ui.log 2>/dev/null || echo "No UI logs found"
        ;;
    *)
        echo "Usage: $0 {api|ui|both}"
        echo "  api  - Show API server logs"
        echo "  ui   - Show UI server logs"
        echo "  both - Show both logs"
        ;;
esac
EOF

chmod +x logs.sh

# Test installation
log "Testing installation..."
python3 -c "
import sys
sys.path.append('.')
try:
    from api.main import app
    from api.data_generator import WebContractDataGenerator
    from api.rag_service import RAGService
    print('✅ All modules imported successfully')
except ImportError as e:
    print(f'❌ Import error: {e}')
    sys.exit(1)
"

# Configure firewall (if firewalld is available)
if command -v firewall-cmd &> /dev/null; then
    log "Configuring firewall..."
    sudo firewall-cmd --permanent --add-port=${API_PORT}/tcp --quiet || true
    sudo firewall-cmd --permanent --add-port=${UI_PORT}/tcp --quiet || true
    sudo firewall-cmd --reload --quiet || true
fi

log "✅ Enhanced Laika Dynamics RAG System deployed successfully!"
log ""
log "🎯 Quick Start Commands:"
log "  ./start.sh   - Start all services"
log "  ./stop.sh    - Stop all services"
log "  ./status.sh  - Check system status"
log "  ./logs.sh    - View system logs"
log ""
log "🌍 Access the system:"
log "  🌐 Web Interface: http://$VPS_IP:$UI_PORT"
log "  📡 API Endpoint:  http://$VPS_IP:$API_PORT"
log "  📚 API Docs:      http://$VPS_IP:$API_PORT/docs"
log ""
log "🚀 Starting the system now..."

# Start the system
./start.sh

log "🎉 Deployment complete! Your enhanced RAG system is ready for demo!" 