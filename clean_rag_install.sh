#!/bin/bash

# Laika Dynamics RAG System - Complete AlmaLinux 9 Installation
set -e

# Configuration
PROJECT_DIR="$HOME/laika-dynamics-rag"
VENV_NAME="laika-rag-env"
API_PORT="8000"
UI_PORT="3000"
VPS_IP="194.238.17.65"

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

# Clean up any existing installations
cleanup_existing() {
    log "Cleaning up any existing installations..."
    
    # Stop any running processes
    pkill -f "uvicorn.*api.main" 2>/dev/null || true
    pkill -f "python.*ui_server.py" 2>/dev/null || true
    pkill -f "streamlit" 2>/dev/null || true
    
    # Remove existing project if it exists
    if [ -d "$PROJECT_DIR" ]; then
        warn "Removing existing project directory: $PROJECT_DIR"
        rm -rf "$PROJECT_DIR"
    fi
    
    sleep 2
    log "Cleanup completed"
}

# System setup for AlmaLinux 9
setup_system() {
    log "Setting up AlmaLinux 9 system..."
    
    # Update system
    sudo dnf update -y
    
    # Install required packages (AlmaLinux 9 specific)
    sudo dnf install -y \
        python3 \
        python3-pip \
        python3-devel \
        git \
        curl \
        wget \
        gcc \
        gcc-c++ \
        make \
        sqlite \
        firewalld \
        unzip
    
    # Enable firewall
    sudo systemctl enable --now firewalld
    
    # Configure firewall
    sudo firewall-cmd --permanent --add-port=$API_PORT/tcp
    sudo firewall-cmd --permanent --add-port=$UI_PORT/tcp
    sudo firewall-cmd --reload
    
    log "System setup completed"
}

# Setup project structure
setup_project() {
    log "Creating project structure..."
    
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    # Create directory structure
    mkdir -p {data/uploads,data/processed,configs,scripts,api,ui,logs}
    
    # Create virtual environment
    python3 -m venv $VENV_NAME
    source $VENV_NAME/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip
    
    log "Project structure created"
}

# Install Python dependencies
install_dependencies() {
    log "Installing Python dependencies..."
    cd "$PROJECT_DIR"
    source $VENV_NAME/bin/activate
    
    # Create requirements.txt with compatible versions
    cat > requirements.txt << 'EOF'
# Core FastAPI and server
fastapi==0.104.1
uvicorn[standard]==0.24.0
python-multipart==0.0.6

# AI and ML - Updated compatible versions
openai==1.6.1
langchain==0.0.335
langchain-openai==0.0.2
langchain-community==0.0.3
sentence-transformers==2.2.2
chromadb==0.4.18

# Data processing
pandas==2.1.3
numpy==1.25.2
scikit-learn==1.3.2

# Utilities
python-dotenv==1.0.0
pyyaml==6.0.1
aiofiles==23.2.1
httpx==0.25.2
psutil==5.9.6
jinja2==3.1.2
EOF
    
    # Install dependencies in correct order to avoid conflicts
    log "Installing core dependencies first..."
    pip install fastapi==0.104.1 uvicorn[standard]==0.24.0 python-multipart==0.0.6
    
    log "Installing AI/ML dependencies..."
    pip install openai==1.6.1
    pip install langchain==0.0.335 langchain-openai==0.0.2 langchain-community==0.0.3
    pip install sentence-transformers==2.2.2 chromadb==0.4.18
    
    log "Installing data processing dependencies..."
    pip install pandas==2.1.3 numpy==1.25.2 scikit-learn==1.3.2
    
    log "Installing utility dependencies..."
    pip install python-dotenv==1.0.0 pyyaml==6.0.1 aiofiles==23.2.1 httpx==0.25.2 psutil==5.9.6 jinja2==3.1.2
    
    log "Dependencies installed successfully"
}

# Create the main API application
create_api() {
    log "Creating RAG API application..."
    cd "$PROJECT_DIR"
    
    cat > api/main.py << 'EOF'
import os
import json
import pandas as pd
from pathlib import Path
from typing import List, Optional
from datetime import datetime

from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse
import psutil
import platform

# AI imports - Robust version with fallbacks
try:
    from langchain_openai import OpenAIEmbeddings, OpenAI
    USING_NEW_LANGCHAIN = True
except ImportError:
    from langchain.embeddings import OpenAIEmbeddings
    from langchain.llms import OpenAI
    USING_NEW_LANGCHAIN = False

try:
    from langchain_community.vectorstores import Chroma
except ImportError:
    from langchain.vectorstores import Chroma

from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.chains import RetrievalQA
from langchain.schema import Document

app = FastAPI(
    title="Laika Dynamics RAG System",
    version="2.0.0",
    description="Advanced RAG System with OpenAI Integration"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global variables
openai_api_key = None

class RAGSystem:
    def __init__(self):
        self.embeddings = None
        self.vector_store = None
        self.qa_chain = None
        self.documents = []
    
    def set_openai_key(self, api_key: str):
        global openai_api_key
        try:
            openai_api_key = api_key
            os.environ["OPENAI_API_KEY"] = api_key
            
            # Try different embedding models based on availability
            embedding_models = [
                "text-embedding-3-small",     # Newer, more widely available
                "text-embedding-ada-002",     # Legacy model
                "text-embedding-3-large"      # Premium model
            ]
            
            for model in embedding_models:
                try:
                    print(f"Trying embedding model: {model}")
                    
                    # Initialize embeddings based on available imports
                    if USING_NEW_LANGCHAIN:
                        self.embeddings = OpenAIEmbeddings(api_key=api_key, model=model)
                    else:
                        self.embeddings = OpenAIEmbeddings(openai_api_key=api_key, model=model)
                    
                    # Test the embeddings with a simple query
                    test_result = self.embeddings.embed_query("test")
                    print(f"✅ Success with {model}! Vector length: {len(test_result)}")
                    return True
                    
                except Exception as e:
                    print(f"❌ Model {model} failed: {str(e)}")
                    continue
            
            # If all models fail, try without specifying model (use default)
            try:
                print("Trying default embedding model...")
                if USING_NEW_LANGCHAIN:
                    self.embeddings = OpenAIEmbeddings(api_key=api_key)
                else:
                    self.embeddings = OpenAIEmbeddings(openai_api_key=api_key)
                
                test_result = self.embeddings.embed_query("test")
                print(f"✅ Success with default model! Vector length: {len(test_result)}")
                return True
                
            except Exception as e:
                print(f"❌ Default model also failed: {str(e)}")
                return False
            
        except Exception as e:
            print(f"Error setting OpenAI key: {e}")
            import traceback
            traceback.print_exc()
            return False
    
    def process_csv(self, file_path: str):
        try:
            print(f"Processing CSV: {file_path}")
            
            if not self.embeddings:
                print("Error: Embeddings not initialized")
                return False
            
            # Load CSV with error handling
            try:
                df = pd.read_csv(file_path)
                print(f"CSV loaded successfully. Shape: {df.shape}")
                print(f"Columns: {list(df.columns)}")
            except Exception as e:
                print(f"Error loading CSV: {e}")
                return False
            
            if df.empty:
                print("Error: CSV file is empty")
                return False
            
            # Convert to text documents
            documents = []
            for idx, row in df.iterrows():
                text_parts = []
                for col, val in row.items():
                    if pd.notna(val) and str(val).strip():
                        text_parts.append(f"{col}: {str(val).strip()}")
                
                if text_parts:  # Only add if there's content
                    text = " | ".join(text_parts)
                    documents.append(text)
            
            print(f"Created {len(documents)} text documents")
            
            if not documents:
                print("Error: No valid documents created from CSV")
                return False
            
            # Split documents
            text_splitter = RecursiveCharacterTextSplitter(
                chunk_size=500,  # Smaller chunks for better processing
                chunk_overlap=50
            )
            
            split_docs = []
            for doc in documents:
                if doc.strip():
                    splits = text_splitter.split_text(doc)
                    split_docs.extend(splits)
            
            print(f"Split into {len(split_docs)} chunks")
            
            if not split_docs:
                print("Error: No valid document chunks created")
                return False
            
            # Create vector store with retry logic
            max_retries = 3
            for attempt in range(max_retries):
                try:
                    print(f"Creating vector store (attempt {attempt + 1}/{max_retries})...")
                    
                    # Ensure directory exists
                    os.makedirs("./data/chroma_db", exist_ok=True)
                    
                    self.vector_store = Chroma.from_texts(
                        texts=split_docs[:50],  # Limit to first 50 chunks for testing
                        embedding=self.embeddings,
                        persist_directory="./data/chroma_db"
                    )
                    print("Vector store created successfully")
                    break
                    
                except Exception as e:
                    print(f"Attempt {attempt + 1} failed: {e}")
                    if attempt == max_retries - 1:
                        print("All attempts failed")
                        return False
                    import time
                    time.sleep(2)  # Wait before retry
            
            # Create QA chain
            try:
                print("Creating QA chain...")
                
                # Try different LLM models based on availability
                llm_models = ["gpt-3.5-turbo", "gpt-4", "gpt-3.5-turbo-instruct"]
                
                for model in llm_models:
                    try:
                        print(f"Trying LLM model: {model}")
                        if USING_NEW_LANGCHAIN:
                            llm = OpenAI(api_key=openai_api_key, model=model, temperature=0)
                        else:
                            llm = OpenAI(openai_api_key=openai_api_key, model=model, temperature=0)
                        
                        self.qa_chain = RetrievalQA.from_chain_type(
                            llm=llm,
                            chain_type="stuff",
                            retriever=self.vector_store.as_retriever(search_kwargs={"k": 3})
                        )
                        print(f"✅ QA chain created successfully with {model}")
                        return True
                        
                    except Exception as e:
                        print(f"❌ LLM model {model} failed: {str(e)}")
                        continue
                
                # If all specific models fail, try default
                try:
                    print("Trying default LLM model...")
                    if USING_NEW_LANGCHAIN:
                        llm = OpenAI(api_key=openai_api_key, temperature=0)
                    else:
                        llm = OpenAI(openai_api_key=openai_api_key, temperature=0)
                    
                    self.qa_chain = RetrievalQA.from_chain_type(
                        llm=llm,
                        chain_type="stuff",
                        retriever=self.vector_store.as_retriever(search_kwargs={"k": 3})
                    )
                    print("✅ QA chain created successfully with default model")
                    return True
                    
                except Exception as e:
                    print(f"❌ Default LLM also failed: {str(e)}")
                    return False
                
            except Exception as e:
                print(f"Error creating QA chain: {e}")
                import traceback
                traceback.print_exc()
                return False
                
        except Exception as e:
            print(f"Error processing CSV: {e}")
            import traceback
            traceback.print_exc()
            return False
    
    def query(self, question: str):
        if not self.qa_chain:
            return "RAG system not initialized. Please upload data and set OpenAI key."
        
        try:
            print(f"Processing query: {question}")
            response = self.qa_chain.run(question)
            print(f"Query response: {response}")
            return response
        except Exception as e:
            error_msg = f"Error processing query: {str(e)}"
            print(error_msg)
            return error_msg

# Initialize RAG system
rag_system = RAGSystem()

@app.post("/api/set-openai-key")
async def set_openai_key(api_key: str = Form(...)):
    try:
        if not api_key or not api_key.startswith('sk-'):
            return {"status": "error", "message": "Invalid OpenAI API key format"}
        
        success = rag_system.set_openai_key(api_key)
        if success:
            return {"status": "success", "message": "OpenAI API key set successfully"}
        else:
            return {"status": "error", "message": "Failed to set OpenAI API key - check logs"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@app.post("/api/upload-csv")
async def upload_csv(file: UploadFile = File(...)):
    try:
        if not file.filename.endswith('.csv'):
            return {"status": "error", "message": "Please upload a CSV file"}
        
        # Ensure uploads directory exists
        os.makedirs("data/uploads", exist_ok=True)
        
        # Save uploaded file
        file_path = f"data/uploads/{file.filename}"
        with open(file_path, "wb") as buffer:
            content = await file.read()
            buffer.write(content)
        
        print(f"File saved to: {file_path}")
        print(f"File size: {len(content)} bytes")
        
        # Check if OpenAI key is set
        if not openai_api_key:
            return {
                "status": "error", 
                "message": "Please set your OpenAI API key first"
            }
        
        # Process CSV
        success = rag_system.process_csv(file_path)
        
        if success:
            return {
                "status": "success", 
                "message": f"CSV file '{file.filename}' processed successfully",
                "file_path": file_path
            }
        else:
            return {
                "status": "error", 
                "message": "Failed to process CSV. Check API logs for details."
            }
    except Exception as e:
        error_msg = f"Error uploading/processing CSV: {str(e)}"
        print(error_msg)
        import traceback
        traceback.print_exc()
        return {"status": "error", "message": error_msg}

@app.post("/api/query")
async def query_rag(question: str = Form(...)):
    try:
        response = rag_system.query(question)
        return {
            "status": "success",
            "question": question,
            "answer": response,
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        return {"status": "error", "message": str(e)}

@app.get("/api/status")
async def get_status():
    return {
        "openai_configured": openai_api_key is not None,
        "vector_store_ready": rag_system.vector_store is not None,
        "qa_chain_ready": rag_system.qa_chain is not None,
        "using_new_langchain": USING_NEW_LANGCHAIN,
        "system": {
            "cpu_percent": psutil.cpu_percent(),
            "memory_percent": psutil.virtual_memory().percent,
            "platform": platform.platform()
        },
        "timestamp": datetime.now().isoformat()
    }

@app.get("/")
async def root():
    return {
        "message": "Laika Dynamics RAG System API",
        "version": "2.0.0",
        "status": "running",
        "endpoints": {
            "ui": "http://194.238.17.65:3000",
            "docs": "http://194.238.17.65:8000/docs",
            "status": "http://194.238.17.65:8000/api/status"
        }
    }

@app.get("/health")
async def health():
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}
EOF

    log "RAG API created successfully"
}

# Create enhanced UI
create_ui() {
    log "Creating enhanced RAG UI..."
    cd "$PROJECT_DIR"
    
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
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container { 
            max-width: 1400px; 
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
            font-size: 2.8rem;
            font-weight: 600;
            background: linear-gradient(135deg, #667eea, #764ba2);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        .status-bar {
            background: linear-gradient(135deg, #27ae60, #2ecc71);
            color: white;
            padding: 15px;
            border-radius: 10px;
            text-align: center;
            margin-bottom: 30px;
            font-weight: 500;
        }
        .grid { 
            display: grid; 
            grid-template-columns: 1fr 1fr; 
            gap: 30px; 
            margin-bottom: 30px; 
        }
        .card { 
            background: white; 
            padding: 30px; 
            border-radius: 15px; 
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
            border: 1px solid #e1e8ed;
            transition: all 0.3s ease;
        }
        .card:hover {
            transform: translateY(-5px);
            box-shadow: 0 15px 40px rgba(0,0,0,0.15);
        }
        .card h3 { 
            color: #2c3e50; 
            margin-bottom: 20px;
            font-size: 1.4rem;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .form-group {
            margin-bottom: 20px;
        }
        .form-group label {
            display: block;
            margin-bottom: 8px;
            font-weight: 500;
            color: #2c3e50;
        }
        .form-group input[type="text"],
        .form-group input[type="password"],
        .form-group input[type="file"],
        .form-group textarea {
            width: 100%;
            padding: 12px;
            border: 2px solid #e1e8ed;
            border-radius: 8px;
            font-size: 14px;
            transition: border-color 0.3s ease;
        }
        .form-group input:focus,
        .form-group textarea:focus {
            outline: none;
            border-color: #667eea;
        }
        .form-group textarea {
            min-height: 120px;
            resize: vertical;
        }
        .btn {
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 8px;
            cursor: pointer;
            font-size: 14px;
            font-weight: 500;
            transition: all 0.3s ease;
            width: 100%;
        }
        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
        }
        .btn:disabled {
            opacity: 0.6;
            cursor: not-allowed;
            transform: none;
        }
        .response-area {
            grid-column: 1 / -1;
        }
        .response-content {
            background: #f8f9fa;
            border: 2px solid #e9ecef;
            border-radius: 8px;
            padding: 20px;
            min-height: 200px;
            font-family: 'Monaco', 'Menlo', monospace;
            font-size: 14px;
            line-height: 1.6;
            white-space: pre-wrap;
            overflow-y: auto;
        }
        .status-indicator {
            display: inline-block;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            margin-right: 8px;
        }
        .status-online { background: #27ae60; }
        .status-offline { background: #e74c3c; }
        .status-warning { background: #f39c12; }
        .system-status {
            background: linear-gradient(135deg, #3498db, #2980b9);
            color: white;
            padding: 20px;
            border-radius: 10px;
            margin-top: 20px;
        }
        .emoji { font-size: 1.5rem; margin-right: 10px; }
        @media (max-width: 968px) {
            .grid { grid-template-columns: 1fr; }
            .container { padding: 20px; }
            h1 { font-size: 2.2rem; }
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Laika Dynamics RAG System</h1>
        
        <div class="status-bar">
            <span id="mainStatus">🔄 Initializing System...</span>
        </div>
        
        <div class="grid">
            <!-- OpenAI Configuration -->
            <div class="card">
                <h3><span class="emoji">🔑</span>OpenAI Configuration</h3>
                <div class="form-group">
                    <label for="openaiKey">OpenAI API Key:</label>
                    <input type="password" id="openaiKey" placeholder="sk-...">
                </div>
                <button class="btn" onclick="setOpenAIKey()">Set API Key</button>
                <div id="keyStatus" style="margin-top: 10px; font-size: 14px;"></div>
            </div>
            
            <!-- CSV Upload -->
            <div class="card">
                <h3><span class="emoji">📊</span>Data Upload</h3>
                <div class="form-group">
                    <label for="csvFile">Upload CSV File:</label>
                    <input type="file" id="csvFile" accept=".csv">
                </div>
                <button class="btn" onclick="uploadCSV()">Process CSV</button>
                <div id="uploadStatus" style="margin-top: 10px; font-size: 14px;"></div>
            </div>
            
            <!-- RAG Query -->
            <div class="card response-area">
                <h3><span class="emoji">🤖</span>Ask Questions</h3>
                <div class="form-group">
                    <label for="question">Your Question:</label>
                    <textarea id="question" placeholder="Ask anything about your uploaded data..."></textarea>
                </div>
                <button class="btn" onclick="queryRAG()">Ask RAG System</button>
            </div>
            
            <!-- Response Area -->
            <div class="card response-area">
                <h3><span class="emoji">💬</span>AI Response</h3>
                <div class="response-content" id="responseArea">
Ready to answer your questions! Please:
1. Set your OpenAI API key
2. Upload a CSV file
3. Ask questions about your data
                </div>
            </div>
        </div>
        
        <!-- System Status -->
        <div class="system-status">
            <h3><span class="emoji">📊</span>System Status</h3>
            <div id="systemStatus">Loading...</div>
        </div>
    </div>

    <script>
        const API_BASE = 'http://194.238.17.65:8000/api';
        
        // Set OpenAI API Key
        async function setOpenAIKey() {
            const apiKey = document.getElementById('openaiKey').value;
            if (!apiKey) {
                alert('Please enter your OpenAI API key');
                return;
            }
            
            try {
                const formData = new FormData();
                formData.append('api_key', apiKey);
                
                const response = await fetch(`${API_BASE}/set-openai-key`, {
                    method: 'POST',
                    body: formData
                });
                
                const result = await response.json();
                
                if (result.status === 'success') {
                    document.getElementById('keyStatus').innerHTML = 
                        '<span style="color: #27ae60;">✅ API Key set successfully!</span>';
                    updateSystemStatus();
                } else {
                    document.getElementById('keyStatus').innerHTML = 
                        '<span style="color: #e74c3c;">❌ ' + result.message + '</span>';
                }
            } catch (error) {
                document.getElementById('keyStatus').innerHTML = 
                    '<span style="color: #e74c3c;">❌ Error: ' + error.message + '</span>';
            }
        }
        
        // Upload CSV
        async function uploadCSV() {
            const fileInput = document.getElementById('csvFile');
            const file = fileInput.files[0];
            
            if (!file) {
                alert('Please select a CSV file');
                return;
            }
            
            try {
                const formData = new FormData();
                formData.append('file', file);
                
                document.getElementById('uploadStatus').innerHTML = 
                    '<span style="color: #3498db;">🔄 Processing CSV...</span>';
                
                const response = await fetch(`${API_BASE}/upload-csv`, {
                    method: 'POST',
                    body: formData
                });
                
                const result = await response.json();
                
                if (result.status === 'success') {
                    document.getElementById('uploadStatus').innerHTML = 
                        '<span style="color: #27ae60;">✅ CSV processed successfully!</span>';
                    updateSystemStatus();
                } else {
                    document.getElementById('uploadStatus').innerHTML = 
                        '<span style="color: #e74c3c;">❌ ' + result.message + '</span>';
                }
            } catch (error) {
                document.getElementById('uploadStatus').innerHTML = 
                    '<span style="color: #e74c3c;">❌ Error: ' + error.message + '</span>';
            }
        }
        
        // Query RAG System
        async function queryRAG() {
            const question = document.getElementById('question').value;
            if (!question.trim()) {
                alert('Please enter a question');
                return;
            }
            
            try {
                document.getElementById('responseArea').textContent = '🔄 Thinking...';
                
                const formData = new FormData();
                formData.append('question', question);
                
                const response = await fetch(`${API_BASE}/query`, {
                    method: 'POST',
                    body: formData
                });
                
                const result = await response.json();
                
                if (result.status === 'success') {
                    document.getElementById('responseArea').textContent = 
                        `Question: ${result.question}\n\nAnswer: ${result.answer}\n\nTimestamp: ${result.timestamp}`;
                } else {
                    document.getElementById('responseArea').textContent = 
                        `Error: ${result.message}`;
                }
            } catch (error) {
                document.getElementById('responseArea').textContent = 
                    `Error: ${error.message}`;
            }
        }
        
        // Update system status
        async function updateSystemStatus() {
            try {
                const response = await fetch(`${API_BASE}/status`);
                const status = await response.json();
                
                let statusHtml = `
                    <p><strong>OpenAI:</strong> ${status.openai_configured ? '✅ Configured' : '❌ Not configured'}</p>
                    <p><strong>Vector Store:</strong> ${status.vector_store_ready ? '✅ Ready' : '❌ Not ready'}</p>
                    <p><strong>QA Chain:</strong> ${status.qa_chain_ready ? '✅ Ready' : '❌ Not ready'}</p>
                    <p><strong>CPU:</strong> ${status.system.cpu_percent}%</p>
                    <p><strong>Memory:</strong> ${status.system.memory_percent}%</p>
                    <p><strong>Last Update:</strong> ${new Date(status.timestamp).toLocaleString()}</p>
                `;
                
                document.getElementById('systemStatus').innerHTML = statusHtml;
                
                // Update main status
                if (status.openai_configured && status.vector_store_ready && status.qa_chain_ready) {
                    document.getElementById('mainStatus').textContent = '✅ RAG System Fully Operational';
                } else {
                    document.getElementById('mainStatus').textContent = '⚠️ RAG System Partially Configured';
                }
                
            } catch (error) {
                document.getElementById('systemStatus').innerHTML = 
                    '<p style="color: #e74c3c;">Unable to fetch status</p>';
            }
        }
        
        // Initialize page
        document.addEventListener('DOMContentLoaded', function() {
            updateSystemStatus();
            setInterval(updateSystemStatus, 30000); // Update every 30 seconds
        });
    </script>
</body>
</html>
EOF

    log "Enhanced RAG UI created successfully"
}

# Create management scripts
create_scripts() {
    log "Creating management scripts..."
    cd "$PROJECT_DIR"
    
    # UI Server
    cat > ui_server.py << 'EOF'
#!/usr/bin/env python3
import http.server
import socketserver
import os
import sys
from pathlib import Path

PORT = 3000
UI_DIR = "ui"

class CustomHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=UI_DIR, **kwargs)
    
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        super().end_headers()

def main():
    script_dir = Path(__file__).parent.absolute()
    os.chdir(script_dir)
    
    if not os.path.exists(UI_DIR):
        print(f"❌ ERROR: {UI_DIR} directory not found!")
        sys.exit(1)
    
    print(f"🌐 Starting RAG UI server on port {PORT}")
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
    
    # Start script
    cat > start.sh << 'EOF'
#!/bin/bash
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$PROJECT_DIR/laika-rag-env"

echo "🚀 Starting Laika Dynamics RAG System..."

cd "$PROJECT_DIR"
source "$VENV_DIR/bin/activate"

# Create logs directory
mkdir -p logs

# Stop any existing processes
pkill -f "uvicorn.*api.main" 2>/dev/null || true
pkill -f "python.*ui_server.py" 2>/dev/null || true

# Start API server
echo "📡 Starting API server..."
nohup uvicorn api.main:app --host 0.0.0.0 --port 8000 --reload > logs/api.log 2>&1 &
echo $! > api.pid

# Start UI server
echo "🌐 Starting UI server..."
nohup python3 ui_server.py > logs/ui.log 2>&1 &
echo $! > ui.pid

sleep 3

echo ""
echo "✅ RAG System Started!"
echo "🌐 Web Interface: http://194.238.17.65:3000"
echo "📡 API Endpoint: http://194.238.17.65:8000"
echo "📚 API Docs: http://194.238.17.65:8000/docs"
echo ""
EOF

    chmod +x start.sh
    
    # Stop script
    cat > stop.sh << 'EOF'
#!/bin/bash
echo "🛑 Stopping RAG System..."

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

echo "✅ All services stopped"
EOF

    chmod +x stop.sh
    
    log "Management scripts created"
}

# Main installation function
main() {
    log "🚀 Starting Laika Dynamics RAG System Installation"
    log "Target: AlmaLinux 9 VPS (194.238.17.65)"
    
    cleanup_existing
    setup_system
    setup_project
    install_dependencies
    create_api
    create_ui
    create_scripts
    
    log ""
    log "✅ RAG SYSTEM INSTALLATION COMPLETE!"
    log ""
    log "🚀 NEXT STEPS:"
    log "1. cd $PROJECT_DIR"
    log "2. ./start.sh"
    log ""
    log "🌍 GLOBAL ACCESS:"
    log "  🌐 Web Interface: http://194.238.17.65:3000"
    log "  📡 API: http://194.238.17.65:8000"
    log ""
    log "🔧 SETUP CHECKLIST:"
    log "  1. Enter your OpenAI API key in the web interface"
    log "  2. Upload your CSV data file"
    log "  3. Start asking questions!"
    log ""
    log "🎯 Perfect for RAG demos and testing!"
}

# Execute main function
main "$@" 