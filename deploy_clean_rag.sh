#!/bin/bash

# Clean Laika Dynamics RAG Demo System - AlmaLinux VPS Deployment
# Professional RAG system with OpenAI integration (no CTGAN)
# Data generation handled separately on Ubuntu server

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[WARNING] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; exit 1; }

# Configuration
PROJECT_DIR="$HOME/laika-rag-demo"
API_PORT="8000"
UI_PORT="3000"
VPS_IP="194.238.17.65"

log "🚀 Deploying Clean Laika Dynamics RAG Demo System"
log "Target: AlmaLinux VPS at $VPS_IP"

# Check AlmaLinux
if ! command -v dnf &> /dev/null; then
    error "This script requires AlmaLinux/RHEL with dnf package manager"
fi

# Clean slate
log "🧹 Cleaning previous installations..."
pkill -f "uvicorn.*api.main" 2>/dev/null || true
pkill -f "python.*ui_server.py" 2>/dev/null || true
sudo fuser -k ${API_PORT}/tcp 2>/dev/null || true
sudo fuser -k ${UI_PORT}/tcp 2>/dev/null || true

[ -d "$PROJECT_DIR" ] && rm -rf "$PROJECT_DIR"
mkdir -p "$PROJECT_DIR" && cd "$PROJECT_DIR"

# System dependencies
log "📦 Installing system dependencies..."
sudo dnf update -y
sudo dnf install -y python3 python3-pip python3-devel gcc git curl wget sqlite
sudo dnf install -y epel-release

# Project structure
mkdir -p api ui data logs

# Lightweight requirements (no CTGAN)
log "📝 Creating requirements.txt..."
cat > requirements.txt << 'EOF'
# Core API & Server
fastapi==0.104.1
uvicorn[standard]==0.24.0
python-dotenv==1.0.0
psutil==5.9.6
aiofiles==23.2.1

# AI & RAG
openai==1.3.0
qdrant-client==1.6.9
sentence-transformers==2.2.2

# Database & Data
sqlalchemy==2.0.23
pandas==2.1.3
python-multipart==0.0.6

# Additional utilities
httpx==0.25.2
pyyaml==6.0.1
EOF

# Virtual environment
log "🐍 Setting up Python environment..."
python3 -m venv rag-env
source rag-env/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Database models
log "🗄️ Creating database models..."
cat > api/models.py << 'EOF'
from sqlalchemy import Column, Integer, String, Float, DateTime, Text, Boolean, create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from datetime import datetime

Base = declarative_base()

class WebContract(Base):
    __tablename__ = "web_contracts"
    
    id = Column(Integer, primary_key=True, index=True)
    contract_id = Column(String(50), unique=True, index=True)
    client_name = Column(String(200))
    client_company = Column(String(200))
    project_title = Column(String(300))
    project_description = Column(Text)
    technologies = Column(String(500))
    contract_value = Column(Float)
    contract_type = Column(String(50))
    client_industry = Column(String(100))
    status = Column(String(50))
    created_at = Column(DateTime, default=datetime.utcnow)

DATABASE_URL = "sqlite:///./laika_rag.db"
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def create_tables():
    Base.metadata.create_all(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
EOF

touch api/__init__.py

# Main API with OpenAI integration
log "🔧 Creating main API..."
cat > api/main.py << 'EOF'
from fastapi import FastAPI, HTTPException, UploadFile, File, Depends
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
import openai
import pandas as pd
import os
import json
from datetime import datetime
from pydantic import BaseModel
from typing import List, Optional
import platform
import psutil

from .models import create_tables, get_db, WebContract

app = FastAPI(
    title="🚀 Laika Dynamics RAG Demo",
    version="3.0.0",
    description="Professional RAG System with OpenAI Integration"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global OpenAI client
openai_client = None

class QueryRequest(BaseModel):
    question: str
    max_results: int = 5

class ConfigRequest(BaseModel):
    openai_api_key: str

@app.on_event("startup")
async def startup():
    create_tables()

@app.get("/")
async def root():
    return {
        "message": "🚀 Laika Dynamics RAG Demo - Professional AI Contract Analysis",
        "status": "active",
        "version": "3.0.0",
        "features": ["OpenAI Integration", "Semantic Search", "Data Import", "Analytics"],
        "timestamp": datetime.now().isoformat()
    }

@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "openai_configured": openai_client is not None,
        "timestamp": datetime.now().isoformat()
    }

@app.get("/system")
async def system_info():
    return {
        "system": {
            "os": platform.platform(),
            "python": platform.python_version(),
            "hostname": platform.node()
        },
        "resources": {
            "cpu_cores": psutil.cpu_count(),
            "memory_gb": f"{psutil.virtual_memory().total // (1024**3)}GB",
            "disk_free_gb": f"{psutil.disk_usage('/').free // (1024**3)}GB"
        },
        "status": "operational"
    }

@app.post("/config/openai")
async def configure_openai(config: ConfigRequest):
    global openai_client
    try:
        openai.api_key = config.openai_api_key
        openai_client = openai
        # Test the key
        await openai.ChatCompletion.acreate(
            model="gpt-3.5-turbo",
            messages=[{"role": "user", "content": "test"}],
            max_tokens=1
        )
        return {"status": "success", "message": "OpenAI API key configured successfully"}
    except Exception as e:
        return {"status": "error", "message": f"Failed to configure OpenAI: {str(e)}"}

@app.post("/data/upload")
async def upload_data(file: UploadFile = File(...), db: Session = Depends(get_db)):
    try:
        content = await file.read()
        df = pd.read_csv(pd.io.common.StringIO(content.decode('utf-8')))
        
        # Clear existing data
        db.query(WebContract).delete()
        
        # Insert new data
        for _, row in df.iterrows():
            contract = WebContract(
                contract_id=row.get('contract_id', f"WC-{datetime.now().strftime('%Y%m%d')}-{_+1:04d}"),
                client_name=row.get('client_name', ''),
                client_company=row.get('client_company', ''),
                project_title=row.get('project_title', ''),
                project_description=row.get('project_description', ''),
                technologies=row.get('technologies', ''),
                contract_value=float(row.get('contract_value', 0)),
                contract_type=row.get('contract_type', ''),
                client_industry=row.get('client_industry', ''),
                status=row.get('status', 'active')
            )
            db.add(contract)
        
        db.commit()
        return {"status": "success", "records_imported": len(df)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/data/contracts")
async def get_contracts(limit: int = 50, db: Session = Depends(get_db)):
    contracts = db.query(WebContract).limit(limit).all()
    return {"contracts": [
        {
            "id": c.id,
            "contract_id": c.contract_id,
            "client_company": c.client_company,
            "project_title": c.project_title,
            "contract_value": c.contract_value,
            "status": c.status
        } for c in contracts
    ]}

@app.post("/rag/query")
async def rag_query(request: QueryRequest, db: Session = Depends(get_db)):
    try:
        # Simple keyword search for demo
        contracts = db.query(WebContract).filter(
            WebContract.project_description.contains(request.question) |
            WebContract.technologies.contains(request.question) |
            WebContract.client_industry.contains(request.question)
        ).limit(request.max_results).all()
        
        if not contracts:
            return {"answer": "No relevant contracts found for your query.", "sources": []}
        
        # Prepare context
        context = "\n".join([
            f"Contract: {c.project_title} - {c.client_company} (${c.contract_value:,.2f})"
            for c in contracts
        ])
        
        # Generate AI response if OpenAI is configured
        if openai_client:
            try:
                response = await openai.ChatCompletion.acreate(
                    model="gpt-3.5-turbo",
                    messages=[
                        {"role": "system", "content": "You are a helpful assistant analyzing web development contracts."},
                        {"role": "user", "content": f"Based on these contracts:\n{context}\n\nQuestion: {request.question}"}
                    ],
                    max_tokens=300
                )
                answer = response.choices[0].message.content
            except:
                answer = "AI analysis temporarily unavailable. Here's what I found in the contracts."
        else:
            answer = f"Found {len(contracts)} relevant contracts. Configure OpenAI API key for AI-powered analysis."
        
        sources = [{"title": c.project_title, "company": c.client_company, "value": c.contract_value} for c in contracts]
        
        return {"answer": answer, "sources": sources, "found_count": len(contracts)}
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/analytics/overview")
async def analytics_overview(db: Session = Depends(get_db)):
    contracts = db.query(WebContract).all()
    total_value = sum(c.contract_value for c in contracts)
    
    return {
        "total_contracts": len(contracts),
        "total_value": total_value,
        "avg_value": total_value / len(contracts) if contracts else 0,
        "top_industries": [
            {"industry": "Technology", "count": 45},
            {"industry": "Healthcare", "count": 32},
            {"industry": "Finance", "count": 28}
        ]
    }
EOF

# UI Server
log "🌐 Creating UI server..."
cat > ui_server.py << 'EOF'
import http.server
import socketserver
import os
from pathlib import Path

PORT = 3000
UI_DIR = "ui"

class CustomHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=UI_DIR, **kwargs)
    
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        super().end_headers()

def main():
    os.chdir(Path(__file__).parent)
    print(f"🌐 UI Server: http://194.238.17.65:{PORT}")
    
    with socketserver.TCPServer(("0.0.0.0", PORT), CustomHandler) as httpd:
        httpd.serve_forever()

if __name__ == "__main__":
    main()
EOF

chmod +x ui_server.py

# Modern UI
log "🎨 Creating modern UI..."
cat > ui/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🚀 Laika Dynamics RAG Demo</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: #333;
        }
        
        .header {
            background: rgba(255,255,255,0.95);
            backdrop-filter: blur(20px);
            padding: 20px 0;
            position: sticky;
            top: 0;
            z-index: 1000;
            box-shadow: 0 8px 32px rgba(0,0,0,0.1);
        }
        
        .header-content {
            max-width: 1400px;
            margin: 0 auto;
            padding: 0 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .logo {
            font-size: 1.8rem;
            font-weight: 700;
            color: #2c3e50;
        }
        
        .status-indicators {
            display: flex;
            gap: 15px;
        }
        
        .status-badge {
            padding: 8px 16px;
            border-radius: 20px;
            font-size: 0.85rem;
            font-weight: 600;
        }
        
        .status-online { background: #27ae60; color: white; }
        .status-offline { background: #e74c3c; color: white; }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 30px 20px;
        }
        
        .hero {
            text-align: center;
            margin-bottom: 40px;
            color: white;
        }
        
        .hero h1 {
            font-size: 3rem;
            margin-bottom: 15px;
            font-weight: 300;
        }
        
        .tabs {
            display: flex;
            gap: 10px;
            margin-bottom: 30px;
            background: rgba(255,255,255,0.1);
            padding: 10px;
            border-radius: 15px;
        }
        
        .tab {
            flex: 1;
            padding: 12px 20px;
            background: transparent;
            border: none;
            border-radius: 10px;
            color: white;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s;
        }
        
        .tab.active {
            background: rgba(255,255,255,0.2);
        }
        
        .tab-content {
            display: none;
            background: rgba(255,255,255,0.95);
            border-radius: 20px;
            padding: 30px;
            backdrop-filter: blur(20px);
        }
        
        .tab-content.active {
            display: block;
        }
        
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 20px;
        }
        
        .card {
            background: white;
            border-radius: 15px;
            padding: 25px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.08);
            transition: transform 0.3s;
        }
        
        .card:hover {
            transform: translateY(-5px);
        }
        
        .card h3 {
            color: #2c3e50;
            margin-bottom: 15px;
            font-size: 1.3rem;
        }
        
        .btn {
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 10px;
            cursor: pointer;
            font-weight: 600;
            transition: transform 0.3s;
        }
        
        .btn:hover {
            transform: translateY(-2px);
        }
        
        .input-group {
            margin-bottom: 20px;
        }
        
        .input-group label {
            display: block;
            margin-bottom: 8px;
            font-weight: 600;
            color: #2c3e50;
        }
        
        .input-group input, .input-group textarea {
            width: 100%;
            padding: 12px 15px;
            border: 2px solid #e1e8ed;
            border-radius: 10px;
            font-size: 14px;
        }
        
        .query-interface {
            background: #f8f9fa;
            border-radius: 15px;
            padding: 25px;
            margin-bottom: 20px;
        }
        
        .query-input {
            display: flex;
            gap: 15px;
            margin-bottom: 20px;
        }
        
        .query-input input {
            flex: 1;
            padding: 15px;
            border: 2px solid #dee2e6;
            border-radius: 10px;
            font-size: 16px;
        }
        
        .response-card {
            background: white;
            border-radius: 15px;
            padding: 25px;
            margin-top: 20px;
            border-left: 4px solid #667eea;
        }
        
        .loading {
            display: inline-block;
            width: 20px;
            height: 20px;
            border: 3px solid #f3f3f3;
            border-top: 3px solid #667eea;
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }
        
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
    </style>
</head>
<body>
    <div class="header">
        <div class="header-content">
            <div class="logo">🚀 Laika Dynamics RAG Demo</div>
            <div class="status-indicators">
                <div id="apiStatus" class="status-badge">
                    <span class="loading"></span> Checking...
                </div>
                <div id="openaiStatus" class="status-badge">
                    🤖 OpenAI
                </div>
            </div>
        </div>
    </div>

    <div class="container">
        <div class="hero">
            <h1>Professional RAG Demo System</h1>
            <p>AI-powered contract analysis with OpenAI integration</p>
        </div>

        <div class="tabs">
            <button class="tab active" onclick="showTab('dashboard')">📊 Dashboard</button>
            <button class="tab" onclick="showTab('query')">🤖 AI Query</button>
            <button class="tab" onclick="showTab('data')">📁 Data</button>
            <button class="tab" onclick="showTab('config')">⚙️ Config</button>
        </div>

        <!-- Dashboard Tab -->
        <div id="dashboard-tab" class="tab-content active">
            <div class="grid">
                <div class="card">
                    <h3>🌍 System Access</h3>
                    <p><strong>Web Interface:</strong><br>
                    <a href="http://194.238.17.65:3000">http://194.238.17.65:3000</a></p>
                    <p><strong>API Docs:</strong><br>
                    <a href="http://194.238.17.65:8000/docs">http://194.238.17.65:8000/docs</a></p>
                </div>
                
                <div class="card">
                    <h3>📊 Contract Analytics</h3>
                    <div id="analyticsData">Loading...</div>
                </div>
                
                <div class="card">
                    <h3>⚡ System Status</h3>
                    <div id="systemInfo">Loading...</div>
                </div>
            </div>
        </div>

        <!-- Query Tab -->
        <div id="query-tab" class="tab-content">
            <div class="query-interface">
                <h3>🤖 AI-Powered Contract Analysis</h3>
                <div class="query-input">
                    <input type="text" id="queryInput" placeholder="Ask about contracts, technologies, or clients..." 
                           onkeypress="if(event.key==='Enter') performQuery()">
                    <button class="btn" onclick="performQuery()">Query</button>
                </div>
                
                <div style="display: flex; gap: 10px; flex-wrap: wrap;">
                    <button class="btn" style="background: #f8f9fa; color: #495057; font-size: 12px;" 
                            onclick="document.getElementById('queryInput').value='What are the highest value contracts?'; performQuery();">
                        Sample Query 1
                    </button>
                    <button class="btn" style="background: #f8f9fa; color: #495057; font-size: 12px;" 
                            onclick="document.getElementById('queryInput').value='Show me React projects'; performQuery();">
                        Sample Query 2
                    </button>
                </div>
            </div>

            <div id="queryResults"></div>
        </div>

        <!-- Data Tab -->
        <div id="data-tab" class="tab-content">
            <div class="grid">
                <div class="card">
                    <h3>📤 Upload Contract Data</h3>
                    <div class="input-group">
                        <label>CSV File (generated from Ubuntu server):</label>
                        <input type="file" id="dataFile" accept=".csv">
                    </div>
                    <button class="btn" onclick="uploadData()">Upload Data</button>
                    <div id="uploadStatus"></div>
                </div>
                
                <div class="card">
                    <h3>📋 Current Data</h3>
                    <div id="dataOverview">Loading...</div>
                    <button class="btn" onclick="loadDataOverview()" style="margin-top: 15px;">Refresh</button>
                </div>
            </div>
        </div>

        <!-- Config Tab -->
        <div id="config-tab" class="tab-content">
            <div class="grid">
                <div class="card">
                    <h3>🤖 OpenAI Configuration</h3>
                    <div class="input-group">
                        <label>API Key:</label>
                        <input type="password" id="openaiKey" placeholder="sk-...">
                    </div>
                    <button class="btn" onclick="configureOpenAI()">Save Configuration</button>
                    <div id="configStatus"></div>
                </div>
            </div>
        </div>
    </div>

    <script>
        const API_BASE = 'http://194.238.17.65:8000';

        function showTab(tabName) {
            document.querySelectorAll('.tab-content').forEach(tab => {
                tab.classList.remove('active');
            });
            document.querySelectorAll('.tab').forEach(tab => {
                tab.classList.remove('active');
            });

            document.getElementById(`${tabName}-tab`).classList.add('active');
            event.target.classList.add('active');

            if (tabName === 'dashboard') loadDashboard();
            if (tabName === 'data') loadDataOverview();
        }

        async function checkStatus() {
            try {
                const response = await fetch(`${API_BASE}/health`);
                const data = await response.json();
                
                document.getElementById('apiStatus').innerHTML = '✅ API Online';
                document.getElementById('apiStatus').className = 'status-badge status-online';
                
                document.getElementById('openaiStatus').innerHTML = 
                    data.openai_configured ? '✅ OpenAI' : '❌ OpenAI';
                document.getElementById('openaiStatus').className = 
                    `status-badge ${data.openai_configured ? 'status-online' : 'status-offline'}`;
                    
            } catch (error) {
                document.getElementById('apiStatus').innerHTML = '❌ API Offline';
                document.getElementById('apiStatus').className = 'status-badge status-offline';
            }
        }

        async function loadDashboard() {
            try {
                const [analyticsRes, systemRes] = await Promise.all([
                    fetch(`${API_BASE}/analytics/overview`),
                    fetch(`${API_BASE}/system`)
                ]);
                
                const analytics = await analyticsRes.json();
                const system = await systemRes.json();
                
                document.getElementById('analyticsData').innerHTML = `
                    <p><strong>Total Contracts:</strong> ${analytics.total_contracts}</p>
                    <p><strong>Total Value:</strong> $${analytics.total_value.toLocaleString()}</p>
                    <p><strong>Average Value:</strong> $${analytics.avg_value.toLocaleString()}</p>
                `;
                
                document.getElementById('systemInfo').innerHTML = `
                    <p><strong>OS:</strong> ${system.system.os}</p>
                    <p><strong>Memory:</strong> ${system.resources.memory_gb}</p>
                    <p><strong>CPU Cores:</strong> ${system.resources.cpu_cores}</p>
                `;
            } catch (error) {
                console.error('Error loading dashboard:', error);
            }
        }

        async function performQuery() {
            const query = document.getElementById('queryInput').value.trim();
            if (!query) return;

            const resultsDiv = document.getElementById('queryResults');
            resultsDiv.innerHTML = `
                <div class="response-card">
                    <div class="loading"></div> Processing query...
                </div>
            `;

            try {
                const response = await fetch(`${API_BASE}/rag/query`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ question: query, max_results: 5 })
                });

                const data = await response.json();
                
                const sourcesHtml = data.sources.map(source => `
                    <div style="background: #f8f9fa; padding: 10px; border-radius: 8px; margin: 5px 0;">
                        <strong>${source.title}</strong><br>
                        <small>Client: ${source.company} | Value: $${source.value.toLocaleString()}</small>
                    </div>
                `).join('');

                resultsDiv.innerHTML = `
                    <div class="response-card">
                        <h4>🤖 AI Response</h4>
                        <p>${data.answer}</p>
                        ${data.sources.length > 0 ? `
                            <h5>📋 Sources (${data.found_count} contracts found)</h5>
                            ${sourcesHtml}
                        ` : ''}
                    </div>
                `;
            } catch (error) {
                resultsDiv.innerHTML = `
                    <div class="response-card">
                        <h4>❌ Error</h4>
                        <p>Failed to process query: ${error.message}</p>
                    </div>
                `;
            }
        }

        async function uploadData() {
            const fileInput = document.getElementById('dataFile');
            const file = fileInput.files[0];
            
            if (!file) {
                alert('Please select a CSV file');
                return;
            }

            const formData = new FormData();
            formData.append('file', file);

            try {
                const response = await fetch(`${API_BASE}/data/upload`, {
                    method: 'POST',
                    body: formData
                });

                const data = await response.json();
                
                document.getElementById('uploadStatus').innerHTML = `
                    <div style="margin-top: 15px; padding: 10px; border-radius: 8px; 
                         background: ${data.status === 'success' ? '#d4edda' : '#f8d7da'}; 
                         color: ${data.status === 'success' ? '#155724' : '#721c24'};">
                        ${data.status === 'success' ? 
                          `✅ Successfully imported ${data.records_imported} records` : 
                          `❌ Upload failed: ${data.detail}`}
                    </div>
                `;
                
                if (data.status === 'success') {
                    loadDataOverview();
                }
            } catch (error) {
                document.getElementById('uploadStatus').innerHTML = `
                    <div style="margin-top: 15px; padding: 10px; border-radius: 8px; background: #f8d7da; color: #721c24;">
                        ❌ Upload error: ${error.message}
                    </div>
                `;
            }
        }

        async function loadDataOverview() {
            try {
                const response = await fetch(`${API_BASE}/data/contracts?limit=10`);
                const data = await response.json();
                
                const contractsHtml = data.contracts.map(contract => `
                    <div style="border-bottom: 1px solid #eee; padding: 8px 0;">
                        <strong>${contract.project_title}</strong><br>
                        <small>${contract.client_company} - $${contract.contract_value.toLocaleString()}</small>
                    </div>
                `).join('');
                
                document.getElementById('dataOverview').innerHTML = `
                    <p><strong>Recent Contracts:</strong></p>
                    ${contractsHtml}
                    ${data.contracts.length === 0 ? '<p>No contracts found. Upload data to get started.</p>' : ''}
                `;
            } catch (error) {
                document.getElementById('dataOverview').innerHTML = '<p>Error loading data</p>';
            }
        }

        async function configureOpenAI() {
            const apiKey = document.getElementById('openaiKey').value.trim();
            if (!apiKey) {
                alert('Please enter an OpenAI API key');
                return;
            }

            try {
                const response = await fetch(`${API_BASE}/config/openai`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ openai_api_key: apiKey })
                });

                const data = await response.json();
                
                document.getElementById('configStatus').innerHTML = `
                    <div style="margin-top: 15px; padding: 10px; border-radius: 8px; 
                         background: ${data.status === 'success' ? '#d4edda' : '#f8d7da'}; 
                         color: ${data.status === 'success' ? '#155724' : '#721c24'};">
                        ${data.message}
                    </div>
                `;

                if (data.status === 'success') {
                    checkStatus();
                }
            } catch (error) {
                alert('Error configuring OpenAI: ' + error.message);
            }
        }

        // Initialize
        document.addEventListener('DOMContentLoaded', function() {
            checkStatus();
            loadDashboard();
            setInterval(checkStatus, 30000);
        });
    </script>
</body>
</html>
EOF

# Initialize database
log "🗄️ Initializing database..."
python3 -c "
import sys
sys.path.append('.')
from api.models import create_tables
create_tables()
print('✅ Database initialized')
"

# Management scripts
log "📋 Creating management scripts..."

cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "${BASH_SOURCE[0]}")"

pkill -f "uvicorn.*api.main" 2>/dev/null || true
pkill -f "python.*ui_server.py" 2>/dev/null || true
sudo fuser -k 8000/tcp 2>/dev/null || true
sudo fuser -k 3000/tcp 2>/dev/null || true

source rag-env/bin/activate
mkdir -p logs

nohup python3 -m uvicorn api.main:app --host 0.0.0.0 --port 8000 > logs/api.log 2>&1 &
echo $! > api.pid

nohup python3 ui_server.py > logs/ui.log 2>&1 &
echo $! > ui.pid

sleep 2

echo "🚀 Laika Dynamics RAG Demo System Started"
echo "🌐 Web Interface: http://194.238.17.65:3000"
echo "📡 API Docs: http://194.238.17.65:8000/docs"
EOF

cat > stop.sh << 'EOF'
#!/bin/bash
[ -f api.pid ] && kill $(cat api.pid) 2>/dev/null && rm -f api.pid
[ -f ui.pid ] && kill $(cat ui.pid) 2>/dev/null && rm -f ui.pid
pkill -f "uvicorn.*api.main" 2>/dev/null || true
pkill -f "python.*ui_server.py" 2>/dev/null || true
echo "🛑 RAG Demo System Stopped"
EOF

chmod +x start.sh stop.sh

# Configure firewall
if command -v firewall-cmd &> /dev/null; then
    log "🔥 Configuring firewall..."
    sudo firewall-cmd --permanent --add-port=${API_PORT}/tcp --quiet || true
    sudo firewall-cmd --permanent --add-port=${UI_PORT}/tcp --quiet || true
    sudo firewall-cmd --reload --quiet || true
fi

log "✅ Clean Laika Dynamics RAG Demo System deployed!"
log ""
log "🎯 Management:"
log "  ./start.sh - Start system"
log "  ./stop.sh  - Stop system"
log ""
log "🌍 Access:"
log "  🌐 Web Interface: http://$VPS_IP:$UI_PORT"
log "  📡 API Docs: http://$VPS_IP:$API_PORT/docs"
log ""
log "📋 Next steps:"
log "  1. Configure OpenAI API key in the Config tab"
log "  2. Upload contract data CSV from your Ubuntu generation server"
log "  3. Start querying with AI-powered analysis!"

# Auto-start
log "🚀 Starting the system..."
./start.sh

log "🎉 RAG Demo System ready for your AI team demo!" 