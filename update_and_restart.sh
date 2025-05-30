#!/bin/bash

# Quick Update and Restart Script for Laika Dynamics RAG System
set -e

PROJECT_DIR="$HOME/laika-dynamics-rag"
VPS_IP="194.238.17.65"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

error() {
    echo -e "${RED}$1${NC}"
}

main() {
    log "🔄 Updating Laika Dynamics RAG System with UI fixes..."
    
    # Check if project directory exists
    if [ ! -d "$PROJECT_DIR" ]; then
        error "Project directory $PROJECT_DIR not found!"
        error "Please run the main setup script first: ./setup_laika_vps.sh"
        exit 1
    fi
    
    cd "$PROJECT_DIR"
    
    # Stop any existing services
    log "Stopping existing services..."
    pkill -f "uvicorn.*api.main" 2>/dev/null || true
    pkill -f "python.*ui_server.py" 2>/dev/null || true
    sleep 2
    
    # Install missing dependencies if needed
    log "Checking Python dependencies..."
    source laika-rag-env/bin/activate
    pip install psutil 2>/dev/null || true
    
    # Create logs directory if not exists
    mkdir -p logs
    
    # Start the updated system
    log "Starting updated system..."
    ./start_rag_system.sh
    
    # Wait a moment for services to start
    sleep 5
    
    # Test the services
    log "Testing services..."
    
    # Test API
    if curl -s "http://$VPS_IP:8000/health" > /dev/null; then
        info "✅ API service is responding"
    else
        warn "❌ API service is not responding"
    fi
    
    # Test UI
    if curl -s "http://$VPS_IP:3000" > /dev/null; then
        info "✅ UI service is responding"
    else
        warn "❌ UI service is not responding"
    fi
    
    info ""
    info "🎉 Update completed!"
    info ""
    info "🌍 Access your system:"
    info "  🌐 Web Interface: http://$VPS_IP:3000"
    info "  📡 API Endpoint:  http://$VPS_IP:8000"
    info "  📚 API Docs:      http://$VPS_IP:8000/docs"
    info "  📊 System Info:   http://$VPS_IP:8000/system"
    info ""
    info "🔧 Management commands:"
    info "  ./start_rag_system.sh start    - Start services"
    info "  ./start_rag_system.sh stop     - Stop services"
    info "  ./start_rag_system.sh status   - Check status"
    info "  ./start_rag_system.sh restart  - Restart services"
}

main "$@" 