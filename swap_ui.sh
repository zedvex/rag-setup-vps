#!/bin/bash

# Easy UI Swapper for Laika Dynamics RAG Demo
# Usage: ./swap_ui.sh [fancy|original]

UI_DIR="ui"
CURRENT_UI="$UI_DIR/index.html"
FANCY_UI="$UI_DIR/fancy_index.html"
ORIGINAL_UI="$UI_DIR/original_index.html"

log() {
    echo -e "\033[0;32m[UI] $1\033[0m"
}

error() {
    echo -e "\033[0;31m[ERROR] $1\033[0m"
    exit 1
}

# Check if we're in the right directory
if [ ! -d "$UI_DIR" ]; then
    error "UI directory not found. Run this from the project root."
fi

case "${1:-fancy}" in
    fancy)
        if [ ! -f "$FANCY_UI" ]; then
            error "Fancy UI not found at $FANCY_UI"
        fi
        
        # Backup current UI if it's not already backed up
        if [ -f "$CURRENT_UI" ] && [ ! -f "$ORIGINAL_UI" ]; then
            log "Backing up original UI..."
            cp "$CURRENT_UI" "$ORIGINAL_UI"
        fi
        
        # Switch to fancy UI
        log "Switching to fancy UI..."
        cp "$FANCY_UI" "$CURRENT_UI"
        log "✅ Fancy UI activated!"
        log "🌐 Refresh your browser to see the new design"
        ;;
        
    original)
        if [ ! -f "$ORIGINAL_UI" ]; then
            error "Original UI backup not found at $ORIGINAL_UI"
        fi
        
        log "Switching to original UI..."
        cp "$ORIGINAL_UI" "$CURRENT_UI"
        log "✅ Original UI restored!"
        log "🌐 Refresh your browser to see the original design"
        ;;
        
    *)
        echo "Usage: $0 [fancy|original]"
        echo ""
        echo "  fancy    - Switch to modern glassmorphism UI"
        echo "  original - Switch back to original UI"
        echo ""
        echo "Current UI files:"
        [ -f "$CURRENT_UI" ] && echo "  ✅ Current: index.html"
        [ -f "$FANCY_UI" ] && echo "  ✅ Fancy: fancy_index.html"
        [ -f "$ORIGINAL_UI" ] && echo "  ✅ Original backup: original_index.html"
        ;;
esac 