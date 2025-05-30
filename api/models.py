"""
Database models for Laika Dynamics RAG System
Web Contracting Data Schema
"""

from sqlalchemy import Column, Integer, String, Float, DateTime, Text, Boolean
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy import create_engine
from datetime import datetime
import os

Base = declarative_base()

class WebContract(Base):
    """Web Contracting Data Model"""
    __tablename__ = "web_contracts"
    
    id = Column(Integer, primary_key=True, index=True)
    
    # Contract Details
    contract_id = Column(String(50), unique=True, index=True)
    client_name = Column(String(200))
    client_email = Column(String(100))
    client_company = Column(String(200))
    contract_type = Column(String(50))  # website, mobile_app, ecommerce, etc.
    
    # Project Specifications
    project_title = Column(String(300))
    project_description = Column(Text)
    project_scope = Column(Text)
    technologies = Column(String(500))  # JSON string of tech stack
    
    # Financial Details
    contract_value = Column(Float)
    hourly_rate = Column(Float)
    estimated_hours = Column(Integer)
    payment_terms = Column(String(100))
    
    # Timeline
    start_date = Column(DateTime)
    estimated_completion = Column(DateTime)
    actual_completion = Column(DateTime, nullable=True)
    
    # Status & Progress
    status = Column(String(50))  # proposal, active, completed, cancelled
    progress_percentage = Column(Float, default=0.0)
    
    # Requirements & Features
    responsive_design = Column(Boolean, default=True)
    cms_required = Column(Boolean, default=False)
    ecommerce_features = Column(Boolean, default=False)
    api_integration = Column(Boolean, default=False)
    seo_optimization = Column(Boolean, default=True)
    
    # Location & Demographics
    client_location = Column(String(100))
    client_industry = Column(String(100))
    project_complexity = Column(String(20))  # simple, medium, complex, enterprise
    
    # Additional Metadata
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    notes = Column(Text, nullable=True)

class DatasetMetadata(Base):
    """Metadata for generated datasets"""
    __tablename__ = "dataset_metadata"
    
    id = Column(Integer, primary_key=True, index=True)
    dataset_name = Column(String(100))
    generation_method = Column(String(50))  # ctgan, faker, manual
    record_count = Column(Integer)
    created_at = Column(DateTime, default=datetime.utcnow)
    file_path = Column(String(300), nullable=True)
    description = Column(Text, nullable=True)

# Database setup
DATABASE_URL = "sqlite:///./laika_rag.db"
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def create_tables():
    """Create all database tables"""
    Base.metadata.create_all(bind=engine)

def get_db():
    """Database session dependency"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close() 