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
            
            # Initialize embeddings based on available imports
            if USING_NEW_LANGCHAIN:
                self.embeddings = OpenAIEmbeddings(api_key=api_key)
            else:
                self.embeddings = OpenAIEmbeddings(openai_api_key=api_key)
            
            # Test the embeddings with a simple query
            test_result = self.embeddings.embed_query("test")
            print(f"OpenAI embeddings test successful. Vector length: {len(test_result)}")
            
            return True
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
                if USING_NEW_LANGCHAIN:
                    llm = OpenAI(api_key=openai_api_key, temperature=0)
                else:
                    llm = OpenAI(openai_api_key=openai_api_key, temperature=0)
                
                self.qa_chain = RetrievalQA.from_chain_type(
                    llm=llm,
                    chain_type="stuff",
                    retriever=self.vector_store.as_retriever(search_kwargs={"k": 3})
                )
                print("QA chain created successfully")
                return True
                
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