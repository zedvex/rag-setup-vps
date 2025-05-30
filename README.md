# 🚀 Laika Dynamics RAG System - AlmaLinux 9

Enterprise-grade RAG (Retrieval Augmented Generation) system optimized for AlmaLinux 9 VPS deployment.

## 🎯 Quick Start

```bash
# Full installation and setup
./setup_laika_almalinux.sh install

# Start the system
./setup_laika_almalinux.sh start

# Check status
./setup_laika_almalinux.sh status
```

## 📋 Available Commands

| Command | Description | Example |
|---------|-------------|---------|
| `install` | Full installation and setup (default) | `./setup_laika_almalinux.sh install` |
| `start` | Start the RAG system services | `./setup_laika_almalinux.sh start` |
| `stop` | Stop the RAG system services | `./setup_laika_almalinux.sh stop` |
| `restart` | Restart the RAG system services | `./setup_laika_almalinux.sh restart` |
| `status` | Show comprehensive system status | `./setup_laika_almalinux.sh status` |
| `logs` | Show system logs | `./setup_laika_almalinux.sh logs` |
| `help` | Show help message | `./setup_laika_almalinux.sh help` |

## 🌍 Access URLs

After installation and starting the system:

- **🌐 Web Interface**: http://194.238.17.65:3000
- **📡 API Endpoint**: http://194.238.17.65:8000  
- **📋 API Documentation**: http://194.238.17.65:8000/docs
- **🐧 AlmaLinux Info**: http://194.238.17.65:8000/almalinux

## 🔧 System Requirements

### Minimum Requirements
- **OS**: AlmaLinux 9 (RHEL-compatible)
- **RAM**: 8GB (minimum 7GB)
- **Storage**: 20GB free space
- **CPU**: 2+ cores recommended
- **Network**: Public internet access

### Automatically Installed
- Python 3.11 (from AppStream)
- Docker CE
- firewalld
- Required Python packages

## 🐧 AlmaLinux 9 Optimizations

This script is specifically optimized for AlmaLinux 9 with:

### ✅ Enterprise Features
- **firewalld** - Enterprise firewall management
- **SELinux** - Enhanced security policies
- **dnf** - Modern package management
- **systemd** - Professional service management
- **AppStream** - Modular Python 3.11 installation
- **EPEL** - Extended package repository

### 🔒 Security Configuration
- Firewall ports automatically opened (3000, 6333, 8000)
- SELinux policies configured for web services
- Production-ready Gunicorn deployment
- Comprehensive access logging

## 📊 Status Monitoring

The `status` command provides comprehensive system information:

```bash
./setup_laika_almalinux.sh status
```

**Displays:**
- Service status (API, Web Interface, Qdrant)
- System information (Firewall, SELinux)
- Access URLs
- API health check
- Process IDs

## 📝 Log Management

View system logs with the `logs` command:

```bash
./setup_laika_almalinux.sh logs
```

**Shows:**
- API logs (`logs/api.log`)
- Web interface logs (`logs/ui.log`) 
- Access logs (`logs/access.log`)
- Error logs (`logs/error.log`)

## 🔄 Service Management

### Start Services
```bash
./setup_laika_almalinux.sh start
```
- Starts API server with Gunicorn (production-ready)
- Starts web interface
- Checks for existing processes to prevent duplicates

### Stop Services
```bash
./setup_laika_almalinux.sh stop
```
- Gracefully stops all services
- Cleans up PID files
- Provides status feedback

### Restart Services
```bash
./setup_laika_almalinux.sh restart
```
- Stops all services
- Waits 3 seconds
- Starts all services

Perfect for remote AI development team demonstrations! 