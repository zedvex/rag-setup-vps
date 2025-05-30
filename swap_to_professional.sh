#!/bin/bash

# Quick UI Swap to Professional Version with Authentication
# Usage: ./swap_to_professional.sh

UI_DIR="ui"
CURRENT_UI="$UI_DIR/index.html"
PROFESSIONAL_UI="$UI_DIR/professional_index.html"
BACKUP_UI="$UI_DIR/backup_index.html"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${CYAN}[PROFESSIONAL] $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check if we're in the right directory
if [ ! -d "$UI_DIR" ]; then
    error "UI directory not found. Run this from the project root."
fi

# Check if professional UI exists
if [ ! -f "$PROFESSIONAL_UI" ]; then
    error "Professional UI not found at $PROFESSIONAL_UI"
fi

# Backup current UI if it exists and backup doesn't exist
if [ -f "$CURRENT_UI" ] && [ ! -f "$BACKUP_UI" ]; then
    log "Backing up current UI..."
    cp "$CURRENT_UI" "$BACKUP_UI"
    success "Current UI backed up"
fi

# Switch to professional UI
log "Switching to Professional RAG Demo UI..."
cp "$PROFESSIONAL_UI" "$CURRENT_UI"

clear
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                  🚀 PROFESSIONAL UI ACTIVATED               ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

success "Professional UI is now live!"
echo ""
info "✨ NEW FEATURES ACTIVATED:"
echo -e "  🔐 Password Protection (laika2025)"
echo -e "  🎨 FontAwesome Icons (no more emojis)"
echo -e "  💾 OpenAI Key Persistence"
echo -e "  🔧 Less transparent cards for better readability"
echo -e "  🧠 Enhanced AI Query Interface"
echo -e "  📊 Professional Dashboard with Analytics"
echo -e "  📁 Data Upload & Management"
echo -e "  ⚙️  Configuration Panel"
echo ""

warn "SECURITY FEATURES:"
echo -e "  🔑 Demo Password: ${YELLOW}laika2025${NC}"
echo -e "  🔒 Authentication Required"
echo -e "  💿 Local Storage for Settings"
echo ""

info "🌐 ACCESS YOUR PROFESSIONAL DEMO:"
echo -e "  Web Interface: ${BLUE}http://194.238.17.65:3000${NC}"
echo -e "  API Docs:      ${BLUE}http://194.238.17.65:8000/docs${NC}"
echo ""

success "Ready for your AI development team demo! 🎯"
echo "" 