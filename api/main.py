"""
Enhanced Laika Dynamics RAG API
Complete RAG system with CTGAN data generation, OpenAI integration, and vector search
"""

from fastapi import FastAPI, HTTPException, Depends, File, UploadFile, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, JSONResponse
from sqlalchemy.orm import Session
import platform
import psutil
import os
import pandas as pd
import json
import asyncio
from datetime import datetime
from typing import List, Dict, Any, Optional
from pydantic import BaseModel

# Import our modules
from .models import create_tables, get_db, WebContract, DatasetMetadata
from .data_generator import WebContractDataGenerator
from .rag_service import RAGService

# Initialize FastAPI
app = FastAPI(
    title="🚀 Laika Dynamics RAG System", 
    version="2.0.0",
    description="Advanced RAG System with CTGAN Data Generation & OpenAI Integration"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize components
data_generator = WebContractDataGenerator()
rag_service = None  # Will be initialized with API key

# Pydantic models for requests
class QueryRequest(BaseModel):
    question: str
    max_results: int = 10

class DataGenerationRequest(BaseModel):
    base_size: int = 500
    synthetic_size: int = 1000
    dataset_name: str = "web_contracts_dataset"

class ConfigRequest(BaseModel):
    openai_api_key: Optional[str] = None

# Global variables for tracking generation status
generation_status = {"status": "idle", "progress": 0, "message": ""}

@app.on_event("startup")
async def startup_event():
    """Initialize database and components"""
    create_tables()
    print("✅ Database tables created")
    
    # Try to initialize RAG service with environment variable
    global rag_service
    rag_service = RAGService()

# ==================== BASIC ENDPOINTS ====================

@app.get("/")
async def root():
    return {
        "message": "🚀 Laika Dynamics RAG System - Advanced AI-Powered Contract Analysis",
        "status": "active",
        "version": "2.0.0",
        "features": [
            "CTGAN Synthetic Data Generation",
            "OpenAI GPT Integration", 
            "Vector Database Search",
            "Advanced RAG Querying",
            "Real-time Analytics"
        ],
        "timestamp": datetime.now().isoformat()
    }

@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "version": "2.0.0",
        "components": {
            "api": "running",
            "database": "connected",
            "vector_db": "available" if rag_service and rag_service.qdrant_client else "not_available",
            "openai": "configured" if rag_service and rag_service.use_openai else "not_configured"
        },
        "timestamp": datetime.now().isoformat()
    }

@app.get("/system")
async def system_info():
    try:
        return {
            "system": {
                "os": platform.system(),
                "os_release": platform.release(),
                "distribution": platform.platform(),
                "architecture": platform.architecture()[0],
                "machine": platform.machine(),
                "processor": platform.processor(),
                "python_version": platform.python_version(),
                "hostname": platform.node()
            },
            "resources": {
                "cpu_count": psutil.cpu_count(),
                "cpu_percent": psutil.cpu_percent(interval=1),
                "memory": {
                    "total": f"{psutil.virtual_memory().total // (1024**3)}GB",
                    "available": f"{psutil.virtual_memory().available // (1024**3)}GB",
                    "percent": psutil.virtual_memory().percent
                },
                "disk": {
                    "total": f"{psutil.disk_usage('/').total // (1024**3)}GB",
                    "free": f"{psutil.disk_usage('/').free // (1024**3)}GB",
                    "percent": psutil.disk_usage('/').percent
                }
            },
            "ai_services": {
                "openai_configured": rag_service.use_openai if rag_service else False,
                "vector_db_status": "connected" if rag_service and rag_service.qdrant_client else "disconnected",
                "local_embeddings": "available" if rag_service and rag_service.local_model else "unavailable"
            },
            "status": "operational",
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        return {"error": str(e), "status": "error"}

# ==================== CONFIGURATION ENDPOINTS ====================

@app.post("/config/openai")
async def configure_openai(config: ConfigRequest):
    """Configure OpenAI API key"""
    global rag_service
    try:
        if config.openai_api_key:
            # Re-initialize RAG service with new API key
            rag_service = RAGService(openai_api_key=config.openai_api_key)
            return {
                "status": "success",
                "message": "OpenAI API key configured successfully",
                "openai_enabled": rag_service.use_openai
            }
        else:
            return {"status": "error", "message": "No API key provided"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@app.get("/config/status")
async def get_config_status():
    """Get current configuration status"""
    return {
        "openai_configured": rag_service.use_openai if rag_service else False,
        "vector_db_available": bool(rag_service and rag_service.qdrant_client),
        "local_embeddings_available": bool(rag_service and rag_service.local_model),
        "collection_stats": rag_service.get_collection_stats() if rag_service else {}
    }

# ==================== DATA GENERATION ENDPOINTS ====================

@app.post("/data/generate")
async def generate_dataset(request: DataGenerationRequest, background_tasks: BackgroundTasks):
    """Generate synthetic dataset using CTGAN"""
    try:
        # Start background task for data generation
        background_tasks.add_task(
            generate_data_background, 
            request.base_size, 
            request.synthetic_size, 
            request.dataset_name
        )
        
        return {
            "status": "started",
            "message": f"Data generation started: {request.base_size} base + {request.synthetic_size} synthetic records",
            "dataset_name": request.dataset_name,
            "check_progress_url": "/data/generation-status"
        }
    except Exception as e:
        return {"status": "error", "message": str(e)}

async def generate_data_background(base_size: int, synthetic_size: int, dataset_name: str):
    """Background task for data generation"""
    global generation_status
    
    try:
        generation_status = {"status": "generating", "progress": 10, "message": "Starting data generation..."}
        
        # Generate dataset
        generation_status = {"status": "generating", "progress": 30, "message": "Generating base dataset..."}
        dataset = data_generator.generate_complete_dataset(base_size, synthetic_size)
        
        generation_status = {"status": "generating", "progress": 60, "message": "Saving dataset..."}
        filepath = data_generator.save_dataset(dataset, f"{dataset_name}.csv")
        
        # Index in vector database if RAG service is available
        if rag_service:
            generation_status = {"status": "generating", "progress": 80, "message": "Indexing in vector database..."}
            await rag_service.index_contracts(dataset)
        
        generation_status = {
            "status": "completed", 
            "progress": 100, 
            "message": f"Successfully generated {len(dataset)} records",
            "filepath": filepath,
            "dataset_stats": {
                "total_records": len(dataset),
                "base_records": len(dataset[dataset['data_source'] == 'base']),
                "synthetic_records": len(dataset[dataset['data_source'] == 'synthetic']),
                "avg_contract_value": float(dataset['contract_value'].mean()),
                "total_value": float(dataset['contract_value'].sum())
            }
        }
        
    except Exception as e:
        generation_status = {
            "status": "error", 
            "progress": 0, 
            "message": f"Generation failed: {str(e)}"
        }

@app.get("/data/generation-status")
async def get_generation_status():
    """Get current data generation status"""
    return generation_status

@app.get("/data/datasets")
async def list_datasets():
    """List available datasets"""
    try:
        datasets = []
        data_dir = "data"
        if os.path.exists(data_dir):
            for filename in os.listdir(data_dir):
                if filename.endswith('.csv'):
                    filepath = os.path.join(data_dir, filename)
                    stats = os.stat(filepath)
                    datasets.append({
                        "filename": filename,
                        "size_mb": round(stats.st_size / (1024*1024), 2),
                        "created": datetime.fromtimestamp(stats.st_ctime).isoformat(),
                        "modified": datetime.fromtimestamp(stats.st_mtime).isoformat()
                    })
        
        return {"datasets": datasets, "count": len(datasets)}
    except Exception as e:
        return {"error": str(e)}

@app.post("/data/upload")
async def upload_dataset(file: UploadFile = File(...)):
    """Upload custom dataset"""
    try:
        if not file.filename.endswith('.csv'):
            raise HTTPException(status_code=400, detail="Only CSV files are supported")
        
        # Save uploaded file
        upload_dir = "data/uploads"
        os.makedirs(upload_dir, exist_ok=True)
        filepath = os.path.join(upload_dir, file.filename)
        
        with open(filepath, "wb") as buffer:
            content = await file.read()
            buffer.write(content)
        
        # Read and validate CSV
        df = pd.read_csv(filepath)
        
        # Index in vector database if RAG service is available
        if rag_service:
            await rag_service.index_contracts(df)
        
        return {
            "status": "success",
            "message": f"Dataset uploaded and indexed successfully",
            "filename": file.filename,
            "records": len(df),
            "columns": list(df.columns)
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ==================== RAG QUERY ENDPOINTS ====================

@app.post("/rag/query")
async def rag_query(request: QueryRequest):
    """Perform RAG query with semantic search and AI response"""
    if not rag_service:
        raise HTTPException(status_code=503, detail="RAG service not available")
    
    try:
        result = await rag_service.rag_query(request.question, max_context_length=4000)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/rag/search")
async def semantic_search(request: QueryRequest):
    """Perform semantic search without AI response"""
    if not rag_service:
        raise HTTPException(status_code=503, detail="RAG service not available")
    
    try:
        results = await rag_service.semantic_search(request.question, request.max_results)
        return {
            "query": request.question,
            "results": results,
            "count": len(results)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/rag/stats")
async def get_rag_stats():
    """Get RAG system statistics"""
    if not rag_service:
        return {"error": "RAG service not available"}
    
    return rag_service.get_collection_stats()

# ==================== ANALYTICS ENDPOINTS ====================

@app.get("/analytics/overview")
async def analytics_overview():
    """Get analytics overview of contract data"""
    try:
        # This would typically query the database
        # For demo, return sample analytics
        return {
            "total_contracts": 2500,
            "total_value": 12500000.00,
            "avg_contract_value": 50000.00,
            "top_industries": [
                {"industry": "Technology", "count": 450, "percentage": 18.0},
                {"industry": "Healthcare", "count": 380, "percentage": 15.2},
                {"industry": "Finance", "count": 320, "percentage": 12.8}
            ],
            "contract_types": [
                {"type": "website", "count": 800, "percentage": 32.0},
                {"type": "web_app", "count": 600, "percentage": 24.0},
                {"type": "ecommerce", "count": 450, "percentage": 18.0}
            ],
            "status_distribution": [
                {"status": "completed", "count": 1200, "percentage": 48.0},
                {"status": "active", "count": 800, "percentage": 32.0},
                {"status": "proposal", "count": 500, "percentage": 20.0}
            ],
            "monthly_revenue": [
                {"month": "2024-01", "revenue": 980000},
                {"month": "2024-02", "revenue": 1200000},
                {"month": "2024-03", "revenue": 1350000}
            ]
        }
    except Exception as e:
        return {"error": str(e)}

# ==================== UI REDIRECT ====================

@app.get("/ui", response_class=HTMLResponse)
async def ui_redirect():
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Laika Dynamics - Redirecting to UI</title>
        <meta http-equiv="refresh" content="0; url=http://194.238.17.65:3000">
        <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; 
                   background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
                   display: flex; align-items: center; justify-content: center; 
                   height: 100vh; margin: 0; color: white; text-align: center; }
            .container { background: rgba(255,255,255,0.1); padding: 40px; 
                        border-radius: 20px; backdrop-filter: blur(10px); }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🚀 Redirecting to Laika Dynamics UI...</h1>
            <p>If you are not redirected automatically, <a href="http://194.238.17.65:3000" style="color: #fff;">click here</a>.</p>
        </div>
    </body>
    </html>
    """

# ==================== EXAMPLE QUERIES ====================

@app.get("/examples/queries")
async def example_queries():
    """Get example RAG queries for testing"""
    return {
        "example_queries": [
            "What are our highest value contracts?",
            "Show me all e-commerce projects from tech companies",
            "What technologies are most commonly used?",
            "Which clients have the largest project budgets?",
            "What's the average project timeline for web apps?",
            "Show me all active contracts in the healthcare industry",
            "What are the most common payment terms?",
            "Which projects required API integration?",
            "Show me contracts completed in the last 6 months",
            "What's the typical hourly rate for complex projects?"
        ],
        "sample_data_topics": [
            "E-commerce platforms",
            "Mobile app development", 
            "WordPress websites",
            "Custom web applications",
            "API development",
            "Corporate websites",
            "Booking systems",
            "Dashboard development"
        ]
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000) 