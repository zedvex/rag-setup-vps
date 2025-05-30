"""
RAG Service with OpenAI Integration
Handles embeddings, vector search, and AI-powered querying
"""

from openai import AsyncOpenAI
import pandas as pd
import numpy as np
from typing import List, Dict, Any, Optional
import os
from datetime import datetime
import json
import sqlite3
from sentence_transformers import SentenceTransformer
import asyncio
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct
import uuid

class RAGService:
    """Advanced RAG service with OpenAI and vector database integration"""
    
    def __init__(self, openai_api_key: str = None):
        # OpenAI setup
        self.openai_api_key = openai_api_key or os.getenv("OPENAI_API_KEY")
        if self.openai_api_key:
            self.openai_client = AsyncOpenAI(api_key=self.openai_api_key)
            self.use_openai = True
            print("✅ OpenAI API configured")
        else:
            self.openai_client = None
            self.use_openai = False
            print("⚠️ OpenAI API key not found, using local embeddings")
        
        # Local embeddings fallback
        try:
            self.local_model = SentenceTransformer('all-MiniLM-L6-v2')
            print("✅ Local embedding model loaded")
        except Exception as e:
            print(f"❌ Error loading local model: {e}")
            self.local_model = None
        
        # Vector database setup
        try:
            self.qdrant_client = QdrantClient(host="localhost", port=6333)
            self.collection_name = "web_contracts"
            print("✅ Qdrant client initialized")
        except Exception as e:
            print(f"⚠️ Qdrant not available: {e}")
            self.qdrant_client = None
        
        # SQLite database for structured data
        self.db_path = "laika_rag.db"
        self.init_vector_storage()

    def init_vector_storage(self):
        """Initialize vector storage collection in Qdrant"""
        if not self.qdrant_client:
            return
        
        try:
            # Check if collection exists
            collections = self.qdrant_client.get_collections()
            collection_exists = any(col.name == self.collection_name for col in collections.collections)
            
            if not collection_exists:
                # Create collection with appropriate vector size
                vector_size = 1536 if self.use_openai else 384  # OpenAI vs local model
                
                self.qdrant_client.create_collection(
                    collection_name=self.collection_name,
                    vectors_config=VectorParams(size=vector_size, distance=Distance.COSINE)
                )
                print(f"✅ Created Qdrant collection: {self.collection_name}")
            else:
                print(f"✅ Qdrant collection exists: {self.collection_name}")
                
        except Exception as e:
            print(f"❌ Error initializing vector storage: {e}")

    async def get_embeddings(self, texts: List[str]) -> List[List[float]]:
        """Get embeddings using OpenAI or local model"""
        if self.use_openai and self.openai_client:
            try:
                response = await self.openai_client.embeddings.create(
                    model="text-embedding-ada-002",
                    input=texts
                )
                return [item.embedding for item in response.data]
            except Exception as e:
                print(f"OpenAI embedding error: {e}, falling back to local model")
        
        # Fallback to local model
        if self.local_model:
            embeddings = self.local_model.encode(texts)
            return embeddings.tolist()
        
        raise Exception("No embedding model available")

    def prepare_document_text(self, contract_data: Dict) -> str:
        """Prepare contract data for embedding"""
        text_parts = [
            f"Contract ID: {contract_data.get('contract_id', '')}",
            f"Client: {contract_data.get('client_name', '')} at {contract_data.get('client_company', '')}",
            f"Project: {contract_data.get('project_title', '')}",
            f"Description: {contract_data.get('project_description', '')}",
            f"Scope: {contract_data.get('project_scope', '')}",
            f"Technologies: {contract_data.get('technologies', '')}",
            f"Industry: {contract_data.get('client_industry', '')}",
            f"Contract Type: {contract_data.get('contract_type', '')}",
            f"Complexity: {contract_data.get('project_complexity', '')}",
            f"Value: ${contract_data.get('contract_value', 0)}",
            f"Status: {contract_data.get('status', '')}",
            f"Location: {contract_data.get('client_location', '')}",
            f"Notes: {contract_data.get('notes', '')}"
        ]
        
        return "\n".join([part for part in text_parts if part.split(": ", 1)[1]])

    async def index_contracts(self, contracts_df: pd.DataFrame) -> Dict[str, Any]:
        """Index contracts in vector database"""
        if not self.qdrant_client:
            return {"error": "Vector database not available"}
        
        try:
            print(f"🔄 Indexing {len(contracts_df)} contracts...")
            
            # Prepare documents for embedding
            documents = []
            metadata = []
            
            for _, contract in contracts_df.iterrows():
                doc_text = self.prepare_document_text(contract.to_dict())
                documents.append(doc_text)
                
                # Prepare metadata
                meta = contract.to_dict()
                # Convert datetime objects to strings
                for key, value in meta.items():
                    if pd.isna(value):
                        meta[key] = ""
                    elif hasattr(value, 'isoformat'):
                        meta[key] = value.isoformat()
                    else:
                        meta[key] = str(value)
                
                metadata.append(meta)
            
            # Get embeddings in batches
            batch_size = 100
            all_embeddings = []
            
            for i in range(0, len(documents), batch_size):
                batch_docs = documents[i:i + batch_size]
                batch_embeddings = await self.get_embeddings(batch_docs)
                all_embeddings.extend(batch_embeddings)
                print(f"✅ Processed batch {i//batch_size + 1}/{(len(documents)-1)//batch_size + 1}")
            
            # Store in Qdrant
            points = []
            for i, (embedding, meta) in enumerate(zip(all_embeddings, metadata)):
                point = PointStruct(
                    id=str(uuid.uuid4()),
                    vector=embedding,
                    payload=meta
                )
                points.append(point)
            
            # Upload to Qdrant in batches
            for i in range(0, len(points), batch_size):
                batch_points = points[i:i + batch_size]
                self.qdrant_client.upsert(
                    collection_name=self.collection_name,
                    points=batch_points
                )
            
            print(f"✅ Successfully indexed {len(contracts_df)} contracts")
            
            return {
                "status": "success",
                "indexed_count": len(contracts_df),
                "collection_name": self.collection_name,
                "timestamp": datetime.now().isoformat()
            }
            
        except Exception as e:
            print(f"❌ Error indexing contracts: {e}")
            return {"error": str(e)}

    async def semantic_search(self, query: str, limit: int = 10) -> List[Dict[str, Any]]:
        """Perform semantic search on indexed contracts"""
        if not self.qdrant_client:
            return []
        
        try:
            # Get query embedding
            query_embedding = await self.get_embeddings([query])
            
            # Search in Qdrant
            search_results = self.qdrant_client.search(
                collection_name=self.collection_name,
                query_vector=query_embedding[0],
                limit=limit
            )
            
            # Format results
            results = []
            for result in search_results:
                contract = result.payload
                contract['similarity_score'] = result.score
                results.append(contract)
            
            return results
            
        except Exception as e:
            print(f"❌ Error in semantic search: {e}")
            return []

    async def rag_query(self, question: str, max_context_length: int = 4000) -> Dict[str, Any]:
        """Perform RAG query with context retrieval and AI response"""
        try:
            # Step 1: Semantic search for relevant contracts
            relevant_contracts = await self.semantic_search(question, limit=5)
            
            if not relevant_contracts:
                return {
                    "answer": "I couldn't find any relevant contracts for your question.",
                    "sources": [],
                    "query": question
                }
            
            # Step 2: Prepare context from retrieved contracts
            context_parts = []
            sources = []
            
            for contract in relevant_contracts:
                context_text = self.prepare_document_text(contract)
                context_parts.append(f"Contract {contract.get('contract_id', 'Unknown')}:\n{context_text}")
                sources.append({
                    "contract_id": contract.get('contract_id'),
                    "client_company": contract.get('client_company'),
                    "project_title": contract.get('project_title'),
                    "similarity_score": contract.get('similarity_score', 0)
                })
            
            context = "\n\n".join(context_parts)
            
            # Truncate context if too long
            if len(context) > max_context_length:
                context = context[:max_context_length] + "..."
            
            # Step 3: Generate AI response
            if self.use_openai and self.openai_client:
                answer = await self.generate_openai_response(question, context)
            else:
                answer = self.generate_fallback_response(question, relevant_contracts)
            
            return {
                "answer": answer,
                "sources": sources,
                "query": question,
                "context_length": len(context),
                "contracts_found": len(relevant_contracts)
            }
            
        except Exception as e:
            print(f"❌ Error in RAG query: {e}")
            return {
                "answer": f"An error occurred: {str(e)}",
                "sources": [],
                "query": question
            }

    async def generate_openai_response(self, question: str, context: str) -> str:
        """Generate response using OpenAI GPT"""
        try:
            prompt = f"""
You are an AI assistant specialized in analyzing web development contracts and business data. 
Use the following contract information to answer the user's question accurately and helpfully.

CONTEXT:
{context}

QUESTION: {question}

INSTRUCTIONS:
- Answer based only on the provided contract data
- Be specific and cite relevant contract details
- If the data doesn't contain enough information, say so
- Provide insights about trends, patterns, or notable findings when relevant
- Format your response clearly and professionally

ANSWER:
"""

            response = await self.openai_client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[
                    {"role": "system", "content": "You are a helpful assistant specializing in web development contract analysis."},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=500,
                temperature=0.3
            )
            
            return response.choices[0].message.content.strip()
            
        except Exception as e:
            print(f"❌ OpenAI API error: {e}")
            return self.generate_fallback_response(question, [])

    def generate_fallback_response(self, question: str, contracts: List[Dict]) -> str:
        """Generate basic response without OpenAI"""
        if not contracts:
            return "I found no relevant contracts for your question. Please try a different query."
        
        # Basic analysis based on retrieved contracts
        total_value = sum(float(c.get('contract_value', 0)) for c in contracts)
        avg_value = total_value / len(contracts) if contracts else 0
        
        contract_types = [c.get('contract_type', 'Unknown') for c in contracts]
        industries = [c.get('client_industry', 'Unknown') for c in contracts]
        
        response = f"""Based on {len(contracts)} relevant contracts I found:

📊 **Summary:**
- Total contract value: ${total_value:,.2f}
- Average contract value: ${avg_value:,.2f}
- Contract types: {', '.join(set(contract_types))}
- Industries: {', '.join(set(industries))}

📋 **Top Contracts:**"""

        for i, contract in enumerate(contracts[:3], 1):
            response += f"""
{i}. {contract.get('project_title', 'Untitled Project')}
   - Client: {contract.get('client_company', 'Unknown')}
   - Value: ${contract.get('contract_value', 0):,.2f}
   - Status: {contract.get('status', 'Unknown')}"""

        return response

    def get_collection_stats(self) -> Dict[str, Any]:
        """Get statistics about the indexed collection"""
        if not self.qdrant_client:
            return {"error": "Vector database not available"}
        
        try:
            collection_info = self.qdrant_client.get_collection(self.collection_name)
            return {
                "collection_name": self.collection_name,
                "points_count": collection_info.points_count,
                "vector_size": collection_info.config.params.vectors.size,
                "distance_metric": collection_info.config.params.vectors.distance.value
            }
        except Exception as e:
            return {"error": str(e)}

# Example usage
if __name__ == "__main__":
    # Initialize RAG service
    rag = RAGService()
    
    # Test with sample data
    sample_contracts = pd.DataFrame([
        {
            'contract_id': 'WC-2024-0001',
            'client_name': 'John Doe',
            'client_company': 'Tech Startup Inc',
            'project_title': 'E-commerce Platform Development',
            'project_description': 'Build a modern e-commerce platform with React and Node.js',
            'technologies': 'React, Node.js, MongoDB',
            'contract_value': 50000,
            'client_industry': 'Technology',
            'status': 'active'
        }
    ])
    
    # Test indexing and querying
    async def test_rag():
        await rag.index_contracts(sample_contracts)
        result = await rag.rag_query("What e-commerce projects do we have?")
        print(result)
    
    # Run test
    # asyncio.run(test_rag()) 