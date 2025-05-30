#!/bin/bash

# Quick UI Swap to Blue-Green Theme
# Usage: ./swap_to_blue.sh

UI_DIR="ui"
CURRENT_UI="$UI_DIR/index.html"
BLUE_UI="$UI_DIR/blue_green_index.html"
BACKUP_UI="$UI_DIR/original_index.html"

log() {
    echo -e "\033[0;36m[SWAP] $1\033[0m"
}

error() {
    echo -e "\033[0;31m[ERROR] $1\033[0m"
    exit 1
}

# Check if we're in the right directory
if [ ! -d "$UI_DIR" ]; then
    error "UI directory not found. Run this from the project root."
fi

# Check if blue-green UI exists
if [ ! -f "$BLUE_UI" ]; then
    error "Blue-green UI not found at $BLUE_UI"
fi

# Backup current UI if it exists and backup doesn't exist
if [ -f "$CURRENT_UI" ] && [ ! -f "$BACKUP_UI" ]; then
    log "Backing up current UI..."
    cp "$CURRENT_UI" "$BACKUP_UI"
fi

# Switch to blue-green UI
log "Switching to blue-green theme..."
cp "$BLUE_UI" "$CURRENT_UI"

log "✅ Blue-green UI activated!"
log "🌊 Beautiful blue-green theme is now live"
log "🌐 Refresh your browser to see the new design"
log ""
log "Access your RAG demo at: http://194.238.17.65:3000" 