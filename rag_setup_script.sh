            <div class="message bot-message">
                <strong>Laika Dynamics Assistant:</strong> Hello! I'm your AI assistant for Laika Dynamics Web Contracting. I can help you with:
                <ul style="margin: 10px 0; padding-left: 20px;">
                    <li>📊 Project analytics and status tracking</li>
                    <li>💰 Financial data and invoice management</li>
                    <li>⏱️ Timeline analysis and resource allocation#!/bin/bash

# RAG Web Contracting Dataset Setup Script for Ray Head Node
# This script creates a synthetic dataset and RAG interface following the blueprint

set -e  # Exit on any error

# Configuration
PROJECT_DIR="$HOME/laika-dynamics-rag"
VENV_NAME="laika-rag-env"
PYTHON_VERSION="3.11"
QDRANT_PORT="6333"
API_PORT="8000"
UI_PORT="3000"
VPS_IP="194.238.17.65"
DOMAIN="laika-dynamics-rag"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check system requirements for VPS
check_vps_requirements() {
    log "Checking VPS system requirements..."
    
    # Check memory
    MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
    if [ $MEMORY_GB -lt 7 ]; then
        warn "VPS has ${MEMORY_GB}GB RAM. 8GB recommended for optimal performance."
    else
        log "Memory check passed: ${MEMORY_GB}GB available"
    fi
    
    # Check disk space
    DISK_AVAIL=$(df -BG / | awk 'NR==2{print $4}' | sed 's/G//')
    if [ $DISK_AVAIL -lt 20 ]; then
        error "Insufficient disk space. Need at least 20GB free, have ${DISK_AVAIL}GB"
    else
        log "Disk space check passed: ${DISK_AVAIL}GB available"
    fi
    
    # Check CPU cores
    CPU_CORES=$(nproc)
    log "CPU cores: $CPU_CORES"
    
    # Update system packages
    log "Updating system packages..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update -y
        sudo apt-get install -y curl wget git python3 python3-pip python3-venv build-essential sqlite3
    elif command -v yum &> /dev/null; then
        sudo yum update -y
        sudo yum install -y curl wget git python3 python3-pip gcc sqlite
    fi
}

# Configure UFW firewall for VPS
configure_firewall() {
    log "Configuring firewall for public access..."
    
    if command -v ufw &> /dev/null; then
        # Enable UFW if not already enabled
        sudo ufw --force enable
        
        # Allow SSH
        sudo ufw allow ssh
        sudo ufw allow 22
        
        # Allow our application ports
        sudo ufw allow $API_PORT comment "Laika Dynamics API"
        sudo ufw allow $UI_PORT comment "Laika Dynamics Web UI"
        sudo ufw allow $QDRANT_PORT comment "Qdrant Vector DB"
        
        # Show status
        sudo ufw status
        log "Firewall configured for ports: $API_PORT, $UI_PORT, $QDRANT_PORT"
    else
        warn "UFW not available. Please manually configure firewall if needed."
    fi
}

# Check if Ray is running (modified for VPS)
check_ray() {
    log "Checking if Ray should be used on VPS..."
    if command -v ray &> /dev/null && ray status &>/dev/null; then
        log "Ray cluster detected and will be used"
    else
        log "No Ray cluster detected. Running in standalone mode (recommended for VPS)"
    fi
}

# Setup project directory
setup_project() {
    log "Setting up project directory: $PROJECT_DIR"
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    # Create directory structure
    mkdir -p {data/synthetic,data/knowledge,configs,scripts,api,ui}
}

# Setup Python environment
setup_python_env() {
    log "Setting up Python virtual environment..."
    cd "$PROJECT_DIR"
    
    # Create virtual environment
    python$PYTHON_VERSION -m venv $VENV_NAME
    source $VENV_NAME/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install core dependencies
    log "Installing Python dependencies..."
    pip install \
        sdv[tabular] \
        llama-index \
        llama-index-vector-stores-qdrant \
        llama-index-embeddings-openai \
        llama-index-llms-ollama \
        llama-index-embeddings-huggingface \
        qdrant-client \
        fastapi \
        uvicorn \
        pandas \
        numpy \
        pyyaml \
        python-dotenv \
        aiofiles \
        httpx \
        ray[default] \
        openai \
        anthropic \
        sqlite3 \
        sqlalchemy \
        psutil \
        torch \
        sentence-transformers
}

# Install Ollama for local LLM (VPS optimized)
install_ollama() {
    log "Installing Ollama for local LLM on VPS..."
    
    if ! command -v ollama &> /dev/null; then
        curl -fsSL https://ollama.ai/install.sh | sh
        
        # Create systemd service for Ollama
        sudo tee /etc/systemd/system/ollama.service > /dev/null <<EOF
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
ExecStart=/usr/local/bin/ollama serve
User=$USER
Group=$USER
Restart=always
RestartSec=3
Environment="OLLAMA_HOST=0.0.0.0:11434"

[Install]
WantedBy=default.target
EOF

        # Enable and start Ollama service
        sudo systemctl daemon-reload
        sudo systemctl enable ollama
        sudo systemctl start ollama
        
        # Wait for service to start
        sleep 10
        
        log "Downloading AI models (this will take several minutes on first run)..."
        # Use smaller model for VPS with limited resources
        ollama pull llama3.1:8b
        log "Downloading embedding model..."
        ollama pull nomic-embed-text
    else
        log "Ollama already installed"
        sudo systemctl start ollama
        # Ensure models are available
        ollama pull llama3.1:8b
        ollama pull nomic-embed-text
    fi
}

# Setup local SQLite database
setup_local_database() {
    log "Setting up local SQLite database..."
    cd "$PROJECT_DIR"
    
    cat > scripts/setup_database.py << 'EOF'
import sqlite3
import pandas as pd
import os
from pathlib import Path

def setup_database():
    """Create SQLite database with synthetic data"""
    db_path = '../data/laika_dynamics.db'
    os.makedirs(os.path.dirname(db_path), exist_ok=True)
    
    conn = sqlite3.connect(db_path)
    
    # Create tables and load CSV data
    csv_files = ['clients', 'projects', 'tickets', 'invoices']
    
    for table_name in csv_files:
        csv_path = f'../data/synthetic/{table_name}.csv'
        if os.path.exists(csv_path):
            df = pd.read_csv(csv_path)
            df.to_sql(table_name, conn, if_exists='replace', index=False)
            print(f"Loaded {len(df)} rows into {table_name} table")
    
    # Create some useful views
    conn.execute("""
    CREATE VIEW IF NOT EXISTS project_summary AS
    SELECT 
        p.project_id,
        p.title,
        c.name as client_name,
        c.industry,
        p.tech_stack,
        p.status,
        p.quoted_hours,
        p.actual_hours,
        ROUND((p.actual_hours * 1.0 / p.quoted_hours), 2) as efficiency_ratio,
        COUNT(t.ticket_id) as total_tickets,
        SUM(CASE WHEN t.closed_at IS NOT NULL THEN 1 ELSE 0 END) as completed_tickets
    FROM projects p
    LEFT JOIN clients c ON p.client_id = c.client_id
    LEFT JOIN tickets t ON p.project_id = t.project_id
    GROUP BY p.project_id
    """)
    
    conn.execute("""
    CREATE VIEW IF NOT EXISTS client_revenue AS
    SELECT 
        c.client_id,
        c.name,
        c.industry,
        c.monthly_recurring_revenue,
        COUNT(p.project_id) as total_projects,
        SUM(p.quoted_hours * 150) as total_quoted_value,
        SUM(CASE WHEN i.payment_status = 'Paid' THEN i.amount_due ELSE 0 END) as paid_amount,
        SUM(CASE WHEN i.payment_status = 'Overdue' THEN i.amount_due ELSE 0 END) as overdue_amount
    FROM clients c
    LEFT JOIN projects p ON c.client_id = p.client_id
    LEFT JOIN invoices i ON c.client_id = i.client_id
    GROUP BY c.client_id
    """)
    
    conn.commit()
    conn.close()
    print("Database setup complete!")

if __name__ == "__main__":
    setup_database()
EOF
    
    chmod +x scripts/setup_database.py
}
# Install and start Qdrant (VPS optimized)
setup_qdrant() {
    log "Setting up Qdrant vector database for VPS..."
    
    # Check if Docker is available and working
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        log "Starting Qdrant with Docker (public access)..."
        # Stop any existing container
        docker stop qdrant-laika 2>/dev/null || true
        docker rm qdrant-laika 2>/dev/null || true
        
        # Start new container with public binding
        docker run -d \
            --name qdrant-laika \
            --restart unless-stopped \
            -p 0.0.0.0:$QDRANT_PORT:6333 \
            -p 0.0.0.0:6334:6334 \
            -v "$PROJECT_DIR/qdrant_storage:/qdrant/storage" \
            qdrant/qdrant:latest
    else
        # Install Docker first
        log "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        
        # Start Docker service
        sudo systemctl start docker
        sudo systemctl enable docker
        
        log "Please run the script again after Docker installation completes"
        exit 0
    fi
    
    # Wait for Qdrant to start
    log "Waiting for Qdrant to start..."
    sleep 15
    
    # Test Qdrant connection
    if curl -s http://localhost:$QDRANT_PORT/health > /dev/null; then
        log "Qdrant started successfully"
    else
        warn "Qdrant may still be starting up..."
    fi
}

# Create schema configuration
create_schema() {
    log "Creating synthetic data schema..."
    
    cat > configs/schema.yaml << 'EOF'
metadata:
  primary_key: null
  
tables:
  clients:
    primary_key: client_id
    columns:
      client_id:
        sdtype: id
      name:
        sdtype: categorical
      industry:
        sdtype: categorical
        choices: ["Technology", "Healthcare", "Finance", "Retail", "Manufacturing", "Education", "Government"]
      billing_address:
        sdtype: text
      monthly_recurring_revenue:
        sdtype: numerical
        min: 1000
        max: 100000
      risk_score:
        sdtype: numerical
        min: 0.1
        max: 1.0
        
  projects:
    primary_key: project_id
    foreign_keys:
      - foreign_key: client_id
        referenced_table: clients
        referenced_column: client_id
    columns:
      project_id:
        sdtype: id
      client_id:
        sdtype: id
      title:
        sdtype: text
      tech_stack:
        sdtype: categorical
        choices: ["React/Node.js", "Python/Django", "Java/Spring", "PHP/Laravel", "Ruby/Rails", ".NET/C#"]
      start_date:
        sdtype: datetime
      due_date:
        sdtype: datetime
      status:
        sdtype: categorical
        choices: ["Planning", "In Progress", "On Hold", "Completed", "Cancelled"]
      quoted_hours:
        sdtype: numerical
        min: 40
        max: 2000
      actual_hours:
        sdtype: numerical
        min: 20
        max: 2500
        
  tickets:
    primary_key: ticket_id
    foreign_keys:
      - foreign_key: project_id
        referenced_table: projects
        referenced_column: project_id
    columns:
      ticket_id:
        sdtype: id
      project_id:
        sdtype: id
      assignee:
        sdtype: categorical
        choices: ["Alice", "Bob", "Charlie", "Diana", "Eve", "Frank", "Grace", "Henry"]
      story_points:
        sdtype: numerical
        min: 1
        max: 13
      priority:
        sdtype: categorical
        choices: ["Low", "Medium", "High", "Critical"]
      created_at:
        sdtype: datetime
      closed_at:
        sdtype: datetime
        
  invoices:
    primary_key: invoice_id
    foreign_keys:
      - foreign_key: client_id
        referenced_table: clients
        referenced_column: client_id
    columns:
      invoice_id:
        sdtype: id
      client_id:
        sdtype: id
      issue_date:
        sdtype: datetime
      due_date:
        sdtype: datetime
      amount_due:
        sdtype: numerical
        min: 500
        max: 50000
      payment_status:
        sdtype: categorical
        choices: ["Pending", "Paid", "Overdue", "Cancelled"]
EOF
}

# Create data generation script
create_data_generator() {
    log "Creating data generation script..."
    
    cat > scripts/generate_data.py << 'EOF'
import pandas as pd
from sdv.tabular import CTGAN
from sdv.metadata import MultiTableMetadata
import yaml
import os
import json
from datetime import datetime, timedelta
import random

def load_schema(schema_path):
    with open(schema_path, 'r') as f:
        return yaml.safe_load(f)

def generate_synthetic_tables(schema_path, output_dir, num_clients=1000):
    """Generate synthetic tables using SDV"""
    
    # Create some seed data first
    print("Creating seed data...")
    
    # Generate clients
    industries = ["Technology", "Healthcare", "Finance", "Retail", "Manufacturing", "Education", "Government"]
    clients_data = []
    for i in range(100):  # Seed with 100 clients
        clients_data.append({
            'client_id': f'CLT_{i:04d}',
            'name': f'Company_{i}',
            'industry': random.choice(industries),
            'billing_address': f'{random.randint(1, 999)} Business St, City {i}',
            'monthly_recurring_revenue': random.randint(1000, 100000),
            'risk_score': round(random.uniform(0.1, 1.0), 2)
        })
    
    clients_df = pd.DataFrame(clients_data)
    
    # Generate projects
    tech_stacks = ["React/Node.js", "Python/Django", "Java/Spring", "PHP/Laravel", "Ruby/Rails", ".NET/C#"]
    statuses = ["Planning", "In Progress", "On Hold", "Completed", "Cancelled"]
    projects_data = []
    
    for i in range(300):  # 300 projects
        start_date = datetime.now() - timedelta(days=random.randint(1, 365))
        projects_data.append({
            'project_id': f'PRJ_{i:04d}',
            'client_id': random.choice(clients_data)['client_id'],
            'title': f'Project {i}: {random.choice(["Web App", "Mobile App", "API", "Dashboard", "Migration"])}',
            'tech_stack': random.choice(tech_stacks),
            'start_date': start_date,
            'due_date': start_date + timedelta(days=random.randint(30, 365)),
            'status': random.choice(statuses),
            'quoted_hours': random.randint(40, 2000),
            'actual_hours': random.randint(20, 2500)
        })
    
    projects_df = pd.DataFrame(projects_data)
    
    # Generate tickets
    assignees = ["Alice", "Bob", "Charlie", "Diana", "Eve", "Frank", "Grace", "Henry"]
    priorities = ["Low", "Medium", "High", "Critical"]
    tickets_data = []
    
    for i in range(1500):  # 1500 tickets
        created_at = datetime.now() - timedelta(days=random.randint(1, 180))
        tickets_data.append({
            'ticket_id': f'TKT_{i:04d}',
            'project_id': random.choice(projects_data)['project_id'],
            'assignee': random.choice(assignees),
            'story_points': random.randint(1, 13),
            'priority': random.choice(priorities),
            'created_at': created_at,
            'closed_at': created_at + timedelta(days=random.randint(1, 30)) if random.random() > 0.3 else None
        })
    
    tickets_df = pd.DataFrame(tickets_data)
    
    # Generate invoices
    payment_statuses = ["Pending", "Paid", "Overdue", "Cancelled"]
    invoices_data = []
    
    for i in range(800):  # 800 invoices
        issue_date = datetime.now() - timedelta(days=random.randint(1, 180))
        invoices_data.append({
            'invoice_id': f'INV_{i:04d}',
            'client_id': random.choice(clients_data)['client_id'],
            'issue_date': issue_date,
            'due_date': issue_date + timedelta(days=30),
            'amount_due': random.randint(500, 50000),
            'payment_status': random.choice(payment_statuses)
        })
    
    invoices_df = pd.DataFrame(invoices_data)
    
    # Save seed data
    os.makedirs(output_dir, exist_ok=True)
    clients_df.to_csv(f'{output_dir}/clients_seed.csv', index=False)
    projects_df.to_csv(f'{output_dir}/projects_seed.csv', index=False)
    tickets_df.to_csv(f'{output_dir}/tickets_seed.csv', index=False)
    invoices_df.to_csv(f'{output_dir}/invoices_seed.csv', index=False)
    
    print("Seed data created. Now scaling up with SDV...")
    
    # Create metadata for SDV
    metadata = MultiTableMetadata()
    metadata.detect_from_dataframes({
        'clients': clients_df,
        'projects': projects_df,
        'tickets': tickets_df,
        'invoices': invoices_df
    })
    
    # Train models and generate larger datasets
    tables = {
        'clients': clients_df,
        'projects': projects_df,
        'tickets': tickets_df,
        'invoices': invoices_df
    }
    
    for table_name, df in tables.items():
        print(f"Training model for {table_name}...")
        model = CTGAN(epochs=10)  # Reduced epochs for speed
        model.fit(df)
        
        # Generate more data
        scale_factor = {
            'clients': 10,    # 1000 clients
            'projects': 33,   # 10000 projects
            'tickets': 67,    # 100000 tickets
            'invoices': 63    # 50000 invoices
        }
        
        synthetic_df = model.sample(len(df) * scale_factor[table_name])
        synthetic_df.to_csv(f'{output_dir}/{table_name}.csv', index=False)
        print(f"Generated {len(synthetic_df)} rows for {table_name}")

if __name__ == "__main__":
    generate_synthetic_tables('../configs/schema.yaml', '../data/synthetic')
EOF

    chmod +x scripts/generate_data.py
}

# Create document generation script
create_doc_generator() {
    log "Creating document generation script..."
    
    cat > scripts/generate_docs.py << 'EOF'
import pandas as pd
import asyncio
import aiofiles
import os
from datetime import datetime
import random
import json

# Document templates
TEMPLATES = {
    "retrospective": """# Sprint Retrospective - Project {title}

**Project ID:** {project_id}
**Tech Stack:** {tech_stack}
**Date:** {date}
**Duration:** 2 weeks

## What Went Well
- Successfully implemented the core {tech_stack} architecture
- Team collaboration was excellent, especially on complex integration tasks
- Code review process caught several potential issues early
- Client feedback was positive on the initial prototype

## What Could Be Improved
- Initial time estimates were too optimistic by approximately 20%
- Testing coverage needs improvement, especially for edge cases
- Communication with stakeholders could be more frequent
- Development environment setup took longer than expected

## Action Items
1. **Improve Estimation Process**: Implement planning poker for better time estimates
2. **Enhance Testing**: Achieve 80% test coverage minimum for all new features
3. **Weekly Stakeholder Updates**: Schedule regular client check-ins every Friday

## Metrics
- Story Points Completed: {story_points}
- Actual Hours: {actual_hours}
- Quoted Hours: {quoted_hours}
- Team Velocity: {velocity}

## Next Sprint Focus
Continue with {tech_stack} development, focusing on performance optimization and user experience improvements.
""",

    "rfp_response": """# RFP Response - {title}

**Client:** {client_name}
**Industry:** {industry}
**Submission Date:** {date}

## Executive Summary
We are pleased to submit our proposal for {title}. Our team has extensive experience in {tech_stack} development and has successfully delivered similar projects for {industry} clients.

## Technical Approach
Our recommended technical stack includes {tech_stack}, which provides:
- Scalability for future growth
- Security compliance with industry standards
- Cost-effective maintenance
- Modern user experience

## Project Timeline
- **Phase 1:** Requirements and Design (2-3 weeks)
- **Phase 2:** Core Development ({quoted_hours} hours estimated)
- **Phase 3:** Testing and QA (20% of development time)
- **Phase 4:** Deployment and Training (1 week)

## Investment
Total project investment: ${amount:,}
Payment terms: 30% upfront, 40% at milestone, 30% on completion

## Why Choose Us
- {industry} industry expertise
- Proven {tech_stack} capabilities
- Agile development methodology
- Post-launch support included

We look forward to partnering with {client_name} on this exciting project.
""",

    "meeting_minutes": """# Project Meeting Minutes - {title}

**Date:** {date}
**Project:** {project_id}
**Attendees:** Project Manager, Tech Lead, {assignee}, Client Representative

## Agenda Items Discussed

### 1. Project Status Update
- Current status: {status}
- Hours consumed: {actual_hours} of {quoted_hours} budgeted
- Key milestones achieved this week

### 2. Technical Decisions
- Confirmed {tech_stack} architecture approach
- Discussed integration with client's existing systems
- Reviewed security requirements for {industry} compliance

### 3. Timeline Review
- Project remains on track for original deadline
- Identified potential risks in upcoming sprint
- Client requested additional feature consideration

### 4. Budget Discussion
- Current spend tracking within approved budget
- Discussed scope change implications
- Approved additional {story_points} story points for new requirements

## Action Items
- [ ] Tech Lead to provide architecture documentation by Friday
- [ ] {assignee} to complete integration testing by next meeting
- [ ] Project Manager to schedule client demo for prototype
- [ ] Review and approve change request for additional features

## Next Meeting
Scheduled for next week, same time. Focus on demo preparation and integration testing results.

## Risks and Issues
- Minor delay possible if integration testing reveals compatibility issues
- Client stakeholder availability for demo needs confirmation
- Resource allocation for new features requires management approval
""",

    "postmortem": """# Post-Mortem: {title}

**Project ID:** {project_id}
**Incident Date:** {date}
**Severity:** Medium
**Duration:** 2 hours
**Status:** Resolved

## Summary
During deployment of {title} using {tech_stack}, we encountered performance issues that affected system responsiveness for approximately 2 hours.

## Impact
- System response time increased by 300%
- {actual_hours} hours of additional debugging required
- Client demo delayed by 1 day
- No data loss occurred

## Root Cause Analysis
The performance degradation was caused by:
1. Database query optimization oversight in {tech_stack} implementation
2. Insufficient load testing with production-scale data
3. Caching configuration not properly applied

## Timeline
- **10:00 AM**: Deployment initiated
- **10:30 AM**: Performance issues first reported
- **11:00 AM**: Incident response team assembled
- **12:30 PM**: Root cause identified
- **12:45 PM**: Fix implemented and tested
- **1:00 PM**: System fully restored

## Resolution
- Optimized database queries reducing load by 75%
- Implemented proper caching strategy
- Added monitoring alerts for similar issues
- Updated deployment checklist

## Preventive Measures
1. **Enhanced Testing**: Implement load testing with production-scale data
2. **Monitoring**: Add performance monitoring dashboards
3. **Process**: Update deployment checklist to include performance validation
4. **Training**: Team training on {tech_stack} performance optimization

## Lessons Learned
- Performance testing with realistic data volumes is critical
- Monitoring and alerting gaps need addressing
- {tech_stack} performance characteristics require better understanding
- Client communication during incidents needs improvement

This incident, while disruptive, provided valuable learning opportunities and system improvements.
"""
}

async def generate_documents(projects_df, clients_df, tickets_df, output_dir):
    """Generate synthetic documents based on project data"""
    
    os.makedirs(output_dir, exist_ok=True)
    
    # Merge dataframes for context
    projects_with_clients = projects_df.merge(clients_df, on='client_id', how='left')
    projects_with_tickets = projects_df.merge(
        tickets_df.groupby('project_id').agg({
            'story_points': 'sum',
            'assignee': 'first'
        }).reset_index(),
        on='project_id',
        how='left'
    )
    
    full_data = projects_with_clients.merge(projects_with_tickets, on='project_id', how='left')
    
    doc_count = 0
    
    for _, project in full_data.iterrows():
        # Generate 2-4 documents per project
        num_docs = random.randint(2, 4)
        
        for i in range(num_docs):
            doc_type = random.choice(list(TEMPLATES.keys()))
            
            # Prepare template variables
            context = {
                'project_id': project['project_id'],
                'title': project['title'],
                'tech_stack': project['tech_stack'],
                'status': project['status'],
                'quoted_hours': int(project.get('quoted_hours', 0)),
                'actual_hours': int(project.get('actual_hours', 0)),
                'client_name': project['name'],
                'industry': project['industry'],
                'story_points': int(project.get('story_points', 0)),
                'assignee': project.get('assignee', 'Team Member'),
                'date': datetime.now().strftime('%Y-%m-%d'),
                'velocity': round(project.get('story_points', 0) / 14, 1),
                'amount': int(project.get('amount_due', project.get('quoted_hours', 0) * 150))
            }
            
            # Generate document content
            content = TEMPLATES[doc_type].format(**context)
            
            # Add metadata header
            metadata = {
                'doc_type': doc_type,
                'project_id': project['project_id'],
                'client_id': project['client_id'],
                'generated_at': datetime.now().isoformat()
            }
            
            doc_content = f"---\n{json.dumps(metadata, indent=2)}\n---\n\n{content}"
            
            # Save document
            filename = f"{doc_type}_{project['project_id']}_{i+1}.md"
            filepath = os.path.join(output_dir, filename)
            
            async with aiofiles.open(filepath, 'w') as f:
                await f.write(doc_content)
            
            doc_count += 1
            
            if doc_count % 100 == 0:
                print(f"Generated {doc_count} documents...")
    
    print(f"Generated {doc_count} total documents")

async def main():
    # Load project data
    projects_df = pd.read_csv('../data/synthetic/projects.csv')
    clients_df = pd.read_csv('../data/synthetic/clients.csv')
    tickets_df = pd.read_csv('../data/synthetic/tickets.csv')
    
    await generate_documents(projects_df, clients_df, tickets_df, '../data/knowledge')

if __name__ == "__main__":
    asyncio.run(main())
EOF

    chmod +x scripts/generate_docs.py
}

# Create RAG ingestion script
create_rag_ingestion() {
    log "Creating RAG ingestion script..."
    
    cat > scripts/ingest_data.py << 'EOF'
import os
import sqlite3
from llama_index.core import SimpleDirectoryReader, VectorStoreIndex, StorageContext, Settings
from llama_index.vector_stores.qdrant import QdrantVectorStore
from llama_index.embeddings.huggingface import HuggingFaceEmbedding
from llama_index.llms.ollama import Ollama
from qdrant_client import QdrantClient
import json

def setup_rag_index(knowledge_dir, db_path, qdrant_host="localhost", qdrant_port=6333):
    """Create and populate Qdrant vector store with documents and structured data"""
    
    print("Setting up local LLM and embeddings...")
    # Configure local models
    Settings.llm = Ollama(model="llama3.1:8b", request_timeout=120.0)
    Settings.embed_model = HuggingFaceEmbedding(model_name="BAAI/bge-large-en-v1.5")
    
    print("Connecting to Qdrant...")
    # Setup Qdrant
    client = QdrantClient(host=qdrant_host, port=qdrant_port)
    vector_store = QdrantVectorStore(client=client, collection_name="laika_dynamics_docs")
    storage_context = StorageContext.from_defaults(vector_store=vector_store)
    
    print("Loading documents...")
    # Load documents
    documents = SimpleDirectoryReader(
        input_dir=knowledge_dir,
        recursive=True,
        required_exts=[".md", ".txt"]
    ).load_data()
    
    print(f"Loaded {len(documents)} documents")
    
    # Extract and add metadata from document headers
    for doc in documents:
        if doc.text.startswith('---'):
            # Extract YAML metadata
            parts = doc.text.split('---', 2)
            if len(parts) >= 3:
                try:
                    metadata = json.loads(parts[1].strip())
                    doc.metadata.update(metadata)
                    doc.text = parts[2].strip()  # Remove metadata from text
                except:
                    pass
    
    # Add structured data as documents
    print("Adding structured data from SQLite...")
    if os.path.exists(db_path):
        conn = sqlite3.connect(db_path)
        
        # Add project summaries as documents
        cursor = conn.execute("SELECT * FROM project_summary LIMIT 100")
        columns = [description[0] for description in cursor.description]
        
        for row in cursor.fetchall():
            project_data = dict(zip(columns, row))
            doc_text = f"""
# Project Summary: {project_data['title']}

**Client:** {project_data['client_name']} ({project_data['industry']})
**Tech Stack:** {project_data['tech_stack']}
**Status:** {project_data['status']}
**Efficiency:** {project_data['efficiency_ratio']} (actual/quoted hours)
**Progress:** {project_data['completed_tickets']}/{project_data['total_tickets']} tickets completed

This project for {project_data['client_name']} in the {project_data['industry']} industry uses {project_data['tech_stack']} technology.
The project status is {project_data['status']} with {project_data['quoted_hours']} quoted hours and {project_data['actual_hours']} actual hours.
"""
            
            from llama_index.core import Document
            doc = Document(
                text=doc_text,
                metadata={
                    "doc_type": "project_summary",
                    "project_id": project_data['project_id'],
                    "client_name": project_data['client_name'],
                    "industry": project_data['industry'],
                    "tech_stack": project_data['tech_stack'],
                    "status": project_data['status']
                }
            )
            documents.append(doc)
        
        conn.close()
    
    print("Creating vector index...")
    # Create index
    index = VectorStoreIndex.from_documents(
        documents,
        storage_context=storage_context,
        show_progress=True
    )
    
    print("Persisting index...")
    # Persist index
    index.storage_context.persist(persist_dir="./storage")
    
    print("RAG index created successfully!")
    return index

if __name__ == "__main__":    
    setup_rag_index("../data/knowledge", "../data/laika_dynamics.db")
EOF

    chmod +x scripts/ingest_data.py
}

# Create FastAPI backend
create_api() {
    log "Creating FastAPI backend..."
    
    cat > api/main.py << 'EOF'
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from llama_index.core import StorageContext, load_index_from_storage
from llama_index.vector_stores.qdrant import QdrantVectorStore
from llama_index.llms.ollama import Ollama
from llama_index.embeddings.huggingface import HuggingFaceEmbedding
from llama_index.core import Settings
from qdrant_client import QdrantClient
import sqlite3
import pandas as pd
import os
from typing import List, Optional
import psutil
import asyncio

app = FastAPI(title="Laika Dynamics Web Contracting RAG API", version="1.0.0")

# Configure CORS for LAN access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global variables
query_engine = None
db_path = "../data/laika_dynamics.db"

class QueryRequest(BaseModel):
    question: str
    filters: Optional[dict] = None
    use_database: Optional[bool] = True

class QueryResponse(BaseModel):
    answer: str
    sources: List[str]
    sql_data: Optional[dict] = None
    system_info: Optional[dict] = None

class SystemStats(BaseModel):
    cpu_percent: float
    memory_percent: float
    disk_usage: float
    gpu_available: bool
    ollama_status: str

def get_system_stats():
    """Get system performance stats for monitoring"""
    try:
        cpu = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory().percent
        disk = psutil.disk_usage('/').percent
        
        # Check if GPU is available
        gpu_available = False
        try:
            import torch
            gpu_available = torch.cuda.is_available()
        except:
            pass
        
        # Check Ollama status
        ollama_status = "running"
        try:
            import httpx
            response = httpx.get("http://localhost:11434/api/tags", timeout=2)
            if response.status_code != 200:
                ollama_status = "error"
        except:
            ollama_status = "offline"
        
        return SystemStats(
            cpu_percent=cpu,
            memory_percent=memory,
            disk_usage=disk,
            gpu_available=gpu_available,
            ollama_status=ollama_status
        )
    except Exception as e:
        return SystemStats(
            cpu_percent=0,
            memory_percent=0,
            disk_usage=0,
            gpu_available=False,
            ollama_status="error"
        )

def query_database(question: str):
    """Query the SQLite database for structured data"""
    if not os.path.exists(db_path):
        return None
    
    try:
        conn = sqlite3.connect(db_path)
        
        # Simple keyword-based SQL generation
        question_lower = question.lower()
        
        if any(word in question_lower for word in ['client', 'customer', 'revenue']):
            df = pd.read_sql("SELECT * FROM client_revenue ORDER BY paid_amount DESC LIMIT 10", conn)
        elif any(word in question_lower for word in ['project', 'status', 'progress']):
            df = pd.read_sql("SELECT * FROM project_summary ORDER BY efficiency_ratio DESC LIMIT 10", conn)
        elif 'overdue' in question_lower or 'late' in question_lower:
            df = pd.read_sql("SELECT * FROM invoices WHERE payment_status = 'Overdue' LIMIT 10", conn)
        else:
            # Default query
            df = pd.read_sql("SELECT * FROM project_summary LIMIT 5", conn)
        
        conn.close()
        return df.to_dict('records') if not df.empty else None
        
    except Exception as e:
        print(f"Database query error: {e}")
        return None

@app.on_event("startup")
async def startup_event():
    global query_engine
    
    # Configure local LLM and embeddings
    Settings.llm = Ollama(model="llama3.1:8b", request_timeout=120.0)
    Settings.embed_model = HuggingFaceEmbedding(model_name="BAAI/bge-large-en-v1.5")
    
    try:
        # Setup Qdrant connection
        client = QdrantClient(host="localhost", port=6333)
        vector_store = QdrantVectorStore(client=client, collection_name="laika_dynamics_docs")
        storage_context = StorageContext.from_defaults(vector_store=vector_store)
        
        # Load existing index
        index = load_index_from_storage(storage_context, storage_dir="../storage")
        query_engine = index.as_query_engine(
            similarity_top_k=6,
            response_mode="tree_summarize"
        )
        
        print("Laika Dynamics RAG system initialized successfully!")
        
    except Exception as e:
        print(f"Failed to initialize RAG system: {e}")
        query_engine = None

@app.post("/query", response_model=QueryResponse)
async def query_documents(request: QueryRequest):
    if query_engine is None:
        raise HTTPException(status_code=503, detail="RAG system not available")
    
    try:
        # Query structured data if requested
        sql_data = None
        if request.use_database:
            sql_data = query_database(request.question)
        
        # Query vector store
        response = await asyncio.get_event_loop().run_in_executor(
            None, query_engine.query, request.question
        )
        
        # Extract source information
        sources = []
        if hasattr(response, 'source_nodes'):
            for node in response.source_nodes:
                if hasattr(node, 'metadata') and 'doc_type' in node.metadata:
                    sources.append(f"{node.metadata.get('doc_type', 'unknown')} - {node.metadata.get('project_id', 'N/A')}")
        
        return QueryResponse(
            answer=str(response),
            sources=sources,
            sql_data=sql_data,
            system_info=get_system_stats().dict()
        )
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Query failed: {str(e)}")

@app.get("/health")
async def health_check():
    stats = get_system_stats()
    return {
        "status": "healthy",
        "rag_available": query_engine is not None,
        "system_stats": stats.dict(),
        "server_ip": "192.168.1.10"
    }

@app.get("/stats", response_model=SystemStats)
async def get_stats():
    return get_system_stats()

@app.get("/database/summary")
async def get_database_summary():
    """Get a summary of the database contents"""
    if not os.path.exists(db_path):
        raise HTTPException(status_code=404, detail="Database not found")
    
    try:
        conn = sqlite3.connect(db_path)
        
        # Get table counts
        tables = {}
        for table in ['clients', 'projects', 'tickets', 'invoices']:
            cursor = conn.execute(f"SELECT COUNT(*) FROM {table}")
            tables[table] = cursor.fetchone()[0]
        
        # Get some quick stats
        cursor = conn.execute("SELECT COUNT(*) as total_projects, AVG(efficiency_ratio) as avg_efficiency FROM project_summary")
        project_stats = cursor.fetchone()
        
        cursor = conn.execute("SELECT SUM(paid_amount) as total_revenue, SUM(overdue_amount) as total_overdue FROM client_revenue")
        revenue_stats = cursor.fetchone()
        
        conn.close()
        
        return {
            "table_counts": tables,
            "total_projects": project_stats[0],
            "average_efficiency": round(project_stats[1], 2) if project_stats[1] else 0,
            "total_revenue": revenue_stats[0] or 0,
            "total_overdue": revenue_stats[1] or 0
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.get("/")
async def root():
    return {
        "message": "Laika Dynamics Web Contracting RAG API",
        "version": "1.0.0",
        "server_ip": "192.168.1.10",
        "endpoints": ["/query", "/health", "/stats", "/database/summary"]
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF
}

# Create simple web UI
create_ui() {
    log "Creating web UI..."
    
    cat > ui/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Web Contracting RAG</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 15px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(135deg, #2c3e50 0%, #34495e 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        
        .header p {
            opacity: 0.8;
            font-size: 1.1em;
        }
        
        .chat-container {
            height: 60vh;
            overflow-y: auto;
            padding: 20px;
            background: #f8f9fa;
        }
        
        .message {
            margin: 15px 0;
            padding: 15px;
            border-radius: 10px;
            max-width: 80%;
        }
        
        .user-message {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            margin-left: auto;
        }
        
        .bot-message {
            background: white;
            border: 1px solid #e9ecef;
            color: #333;
        }
        
        .sources {
            margin-top: 10px;
            padding: 10px;
            background: rgba(0,0,0,0.05);
            border-radius: 5px;
            font-size: 0.9em;
        }
        
        .input-area {
            padding: 20px;
            background: white;
            border-top: 1px solid #e9ecef;
        }
        
        .input-container {
            display: flex;
            gap: 10px;
        }
        
        #questionInput {
            flex: 1;
            padding: 15px;
            border: 2px solid #e9ecef;
            border-radius: 10px;
            font-size: 16px;
            outline: none;
            transition: border-color 0.3s;
        }
        
        #questionInput:focus {
            border-color: #667eea;
        }
        
        #askButton {
            padding: 15px 30px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 10px;
            cursor: pointer;
            font-size: 16px;
            transition: transform 0.2s;
        }
        
        #askButton:hover {
            transform: translateY(-2px);
        }
        
        #askButton:disabled {
            opacity: 0.6;
            cursor: not-allowed;
            transform: none;
        }
        
        .loading {
            display: none;
            text-align: center;
            padding: 20px;
            color: #666;
        }
        
        .spinner {
            display: inline-block;
            width: 20px;
            height: 20px;
            border: 3px solid #f3f3f3;
            border-top: 3px solid #667eea;
            border-radius: 50%;
            animation: spin 1s linear infinite;
            margin-right: 10px;
        }
        
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        
        .examples {
            padding: 20px;
            background: #f8f9fa;
            border-top: 1px solid #e9ecef;
        }
        
        .examples h3 {
            margin-bottom: 15px;
            color: #333;
        }
        
        .example-question {
            background: white;
            padding: 10px 15px;
            margin: 5px 0;
            border-radius: 8px;
            cursor: pointer;
            transition: background-color 0.2s;
            border: 1px solid #e9ecef;
        }
        
        .example-question:hover {
            background: #e9ecef;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Laika Dynamics Web Contracting RAG</h1>
            <p>AI-Powered Business Intelligence | Global Access: 194.238.17.65</p>
        </div>
        
        <div class="chat-container" id="chatContainer">
            <div class="message bot-message">
                <strong>Laika Dynamics Assistant:</strong> Welcome to the Laika Dynamics AI Business Intelligence platform! I'm running on a global VPS and can help you with:
                <ul style="margin: 10px 0; padding-left: 20px;">
                    <li>📊 Project analytics and performance tracking</li>
                    <li>💰 Revenue analysis and financial insights</li>
                    <li>⏱️ Resource optimization and timeline management</li>
                    <li>👥 Team productivity and workload analysis</li>
                    <li>📝 Document search across all project files</li>
                    <li>🎯 Strategic business recommendations</li>
                </ul>
                Powered by local AI models on our VPS for fast, secure responses. What insights can I provide for you today?
            </div>
        </div>
        
        <div class="loading" id="loading">
            <div class="spinner"></div>
            Processing your question...
        </div>
        
        <div class="input-area">
            <div class="input-container">
                <input type="text" id="questionInput" placeholder="Ask a question about your projects, clients, or business data..." />
                <button id="askButton" onclick="askQuestion()">Ask</button>
            </div>
        </div>
        
        <div class="examples">
            <h3>🎯 Example Questions for Demo:</h3>
            <div class="example-question" onclick="setQuestion(this.textContent)">
                What's our total revenue and how much is overdue?
            </div>
            <div class="example-question" onclick="setQuestion(this.textContent)">
                Which technology clients have the highest project efficiency?
            </div>
            <div class="example-question" onclick="setQuestion(this.textContent)">
                Show me recent project post-mortems and lessons learned
            </div>
            <div class="example-question" onclick="setQuestion(this.textContent)">
                What are the main blockers mentioned in sprint retrospectives?
            </div>
            <div class="example-question" onclick="setQuestion(this.textContent)">
                Which React/Node.js projects need attention this week?
            </div>
            <div class="example-question" onclick="setQuestion(this.textContent)">
                Compare our team velocity across different tech stacks
            </div>
        </div>
    </div>

    <script>
        const API_BASE = 'http://194.238.17.65:8000';
        let systemStats = null;
        
        function setQuestion(question) {
            document.getElementById('questionInput').value = question;
        }
        
        function addMessage(content, isUser, sources = [], sqlData = null, systemInfo = null) {
            const chatContainer = document.getElementById('chatContainer');
            const messageDiv = document.createElement('div');
            messageDiv.className = `message ${isUser ? 'user-message' : 'bot-message'}`;
            
            let messageContent = `<strong>${isUser ? 'You' : 'Laika AI'}:</strong> ${content}`;
            
            if (sqlData && sqlData.length > 0) {
                messageContent += `<div class="sources"><strong>📊 Database Results:</strong><br>Found ${sqlData.length} relevant records in our business database</div>`;
            }
            
            if (sources && sources.length > 0) {
                messageContent += `<div class="sources"><strong>📄 Document Sources:</strong><br>${sources.join('<br>')}</div>`;
            }
            
            if (systemInfo && !isUser) {
                messageContent += `<div class="sources"><strong>⚡ VPS Status:</strong> CPU: ${systemInfo.cpu_percent}% | Memory: ${systemInfo.memory_percent}% | AI: ${systemInfo.ollama_status}</div>`;
            }
            
            messageDiv.innerHTML = messageContent;
            chatContainer.appendChild(messageDiv);
            chatContainer.scrollTop = chatContainer.scrollHeight;
        }
        
        async function askQuestion() {
            const input = document.getElementById('questionInput');
            const button = document.getElementById('askButton');
            const loading = document.getElementById('loading');
            const question = input.value.trim();
            
            if (!question) return;
            
            // Add user message
            addMessage(question, true);
            
            // Clear input and disable button
            input.value = '';
            button.disabled = true;
            loading.style.display = 'block';
            
            try {
                const response = await fetch(`${API_BASE}/query`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({ 
                        question: question,
                        use_database: true 
                    })
                });
                
                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }
                
                const data = await response.json();
                addMessage(data.answer, false, data.sources, data.sql_data, data.system_info);
                
            } catch (error) {
                console.error('Error:', error);
                addMessage(`🚨 Connection error: ${error.message}. The Laika Dynamics VPS may be starting up or temporarily unavailable.`, false);
            } finally {
                button.disabled = false;
                loading.style.display = 'none';
            }
        }
        
        // Allow Enter key to submit
        document.getElementById('questionInput').addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                askQuestion();
            }
        });
        
        // Check API health and get stats
        async function checkHealth() {
            try {
                const response = await fetch(`${API_BASE}/health`);
                const data = await response.json();
                
                if (!data.rag_available) {
                    addMessage("⚠️ RAG system is initializing on the VPS. Some features may be limited while the AI models load.", false);
                } else {
                    addMessage(`✅ Laika Dynamics is online and ready! Running on VPS: ${data.server_ip || '194.238.17.65'}`, false);
                }
                
                // Update system stats
                systemStats = data.system_stats;
                
            } catch (error) {
                addMessage(`🚨 Cannot connect to Laika Dynamics VPS. Please wait a moment for the system to start up.`, false);
            }
        }
        
        // Periodic stats update
        async function updateStats() {
            try {
                const response = await fetch(`${API_BASE}/stats`);
                const stats = await response.json();
                systemStats = stats;
                
                // Update UI with stats if needed
                const statusElement = document.querySelector('.header p');
                if (statusElement && stats.ollama_status === 'running') {
                    statusElement.innerHTML = `AI-Powered Business Intelligence | VPS Status: Online ⚡ | Global Access: 194.238.17.65`;
                }
            } catch (error) {
                // Silently fail for stats updates
            }
        }
        
        // Check health when page loads
        window.addEventListener('load', () => {
            checkHealth();
            // Update stats every 30 seconds
            setInterval(updateStats, 30000);
        });
    </script>
</body>
</html>
EOF
}

# Create environment file template
create_env_template() {
    log "Creating environment template..."
    
    cat > .env.template << 'EOF'
# VPS Configuration
VPS_IP=194.238.17.65
API_PORT=8000
UI_PORT=3000
QDRANT_PORT=6333

# Local AI Configuration (no API keys needed!)
OLLAMA_HOST=0.0.0.0
OLLAMA_PORT=11434

# Database Configuration
DATABASE_PATH=./data/laika_dynamics.db

# Optional: OpenAI API (for fallback, not required)
# OPENAI_API_KEY=your_openai_api_key_here
EOF

    log "Environment template created - VPS ready with no API keys required!"
}

# Create startup script
create_startup_script() {
    log "Creating startup script..."
    
    cat > start_rag_system.sh << 'EOF'
#!/bin/bash

# Start the Laika Dynamics RAG system on VPS
cd "$(dirname "$0")"

echo "🚀 Starting Laika Dynamics Web Contracting RAG on VPS..."

# Activate virtual environment
source laika-rag-env/bin/activate

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Check if data exists, generate if not
if [ ! -f "data/synthetic/clients.csv" ]; then
    echo "📊 Generating synthetic business data..."
    cd scripts && python generate_data.py && cd ..
fi

if [ ! -d "data/knowledge" ] || [ -z "$(ls -A data/knowledge)" ]; then
    echo "📝 Generating knowledge documents..."
    cd scripts && python generate_docs.py && cd ..
fi

# Setup local database
if [ ! -f "data/laika_dynamics.db" ]; then
    echo "💾 Setting up local SQLite database..."
    cd scripts && python setup_database.py && cd ..
fi

# Check if vector index exists, create if not
if [ ! -d "storage" ]; then
    echo "🧠 Creating RAG vector index (this may take a few minutes on VPS)..."
    cd scripts && python ingest_data.py && cd ..
fi

# Ensure Ollama is running
echo "🤖 Starting AI service..."
sudo systemctl start ollama
sleep 5

# Verify models are available
echo "🔍 Checking AI models..."
ollama list | grep -q "llama3.1:8b" || ollama pull llama3.1:8b
ollama list | grep -q "nomic-embed-text" || ollama pull nomic-embed-text

# Start Qdrant
echo "🔍 Starting vector database..."
docker start qdrant-laika 2>/dev/null || docker run -d \
    --name qdrant-laika \
    --restart unless-stopped \
    -p 0.0.0.0:6333:6333 \
    -p 0.0.0.0:6334:6334 \
    -v "$(pwd)/qdrant_storage:/qdrant/storage" \
    qdrant/qdrant:latest

sleep 10

echo "🌐 Starting API server (public access)..."
cd api && nohup uvicorn main:app --host 0.0.0.0 --port 8000 > ../api.log 2>&1 &
API_PID=$!
echo $API_PID > ../api.pid

sleep 5

echo "🎨 Starting web interface (public access)..."
cd ../ui && nohup python -m http.server 3000 --bind 0.0.0.0 > ../ui.log 2>&1 &
UI_PID=$!
echo $UI_PID > ../ui.pid

echo ""
echo "🎉 Laika Dynamics RAG System is LIVE on the internet!"
echo ""
echo "🌍 PUBLIC ACCESS URLS:"
echo "   Web Interface: http://194.238.17.65:3000"
echo "   API Endpoint:  http://194.238.17.65:8000"
echo "   API Docs:      http://194.238.17.65:8000/docs"
echo "   Vector DB:     http://194.238.17.65:6333/dashboard"
echo ""
echo "🔧 SYSTEM INFO:"
echo "   VPS: 2 vCPU, 8GB RAM, 100GB NVMe"
echo "   AI: Llama 3.1 8B + BGE embeddings"
echo "   Database: SQLite with 50K+ records"
echo "   Documents: 10K+ synthetic business files"
echo ""
echo "💡 Share these URLs with anyone - they work from anywhere!"
echo "🛑 To stop: ./stop_rag_system.sh"
echo "📝 Logs: api.log, ui.log"
echo ""
echo "System ready for global access! 🌍"
EOFStarting Ollama..."
    ollama serve &
    sleep 5
fi

# Ensure models are available
ollama pull llama3.1:8b >/dev/null 2>&1 &
ollama pull nomic-embed-text >/dev/null 2>&1 &

# Start Qdrant
echo "🔍 Starting vector database..."
if ! pgrep -f "qdrant" > /dev/null; then
    if command -v docker &> /dev/null; then
        docker start qdrant-laika || docker run -d --name qdrant-laika -p 192.168.1.10:6333:6333 -p 192.168.1.10:6334:6334 -v "$(pwd)/qdrant_storage:/qdrant/storage" qdrant/qdrant:latest
    else
        ./qdrant --storage-path ./qdrant_storage --host 0.0.0.0 &
        echo $! > qdrant.pid
    fi
fi

sleep 5

echo "🌐 Starting API server..."
cd api && uvicorn main:app --host 0.0.0.0 --port 8000 &
API_PID=$!
echo $API_PID > ../api.pid

sleep 3

echo "🎨 Starting web interface..."
cd ../ui && python -m http.server 3000 &
UI_PID=$!
echo $UI_PID > ../ui.pid

echo ""
echo "🎉 Laika Dynamics RAG System is live!"
echo "🌐 Web Interface: http://192.168.1.10:3000"
echo "📡 API Endpoint: http://192.168.1.10:8000"
echo "🔍 Qdrant Dashboard: http://192.168.1.10:6333/dashboard"
echo "🤖 Local AI: Llama 3.1 8B + BGE embeddings"
echo ""
echo "💡 Share these URLs with your team for LAN access!"
echo "🛑 To stop: ./stop_rag_system.sh"
echo ""
echo "System is ready for your AI dev team demo! 🚀"
EOF

    chmod +x start_rag_system.sh
}

# Create stop script
create_stop_script() {
    log "Creating stop script..."
    
    cat > stop_rag_system.sh << 'EOF'
#!/bin/bash

echo "🛑 Stopping Laika Dynamics RAG System on VPS..."

# Stop API server
if [ -f api.pid ]; then
    kill $(cat api.pid) 2>/dev/null
    rm api.pid
    echo "✅ API server stopped"
fi

# Stop UI server
if [ -f ui.pid ]; then
    kill $(cat ui.pid) 2>/dev/null
    rm ui.pid
    echo "✅ Web interface stopped"
fi

# Stop Qdrant Docker container
docker stop qdrant-laika 2>/dev/null && echo "✅ Qdrant stopped"

# Optionally stop Ollama (comment out if you want to keep it running)
# sudo systemctl stop ollama && echo "✅ Ollama stopped"

echo "🎉 Laika Dynamics RAG System stopped."
echo "💡 Ollama service left running for faster restarts"
echo "💡 To fully stop all services: sudo systemctl stop ollama"
EOF

    chmod +x stop_rag_system.sh
}

# Main execution
main() {
    log "🚀 Starting Laika Dynamics VPS Setup"
    log "Target VPS: $VPS_IP"
    log "Project directory: $PROJECT_DIR"
    
    # Check VPS requirements and setup
    check_vps_requirements
    configure_firewall
    check_ray
    
    # Setup project structure
    setup_project
    setup_python_env
    install_ollama
    setup_local_database
    setup_qdrant
    
    # Create configuration and scripts
    create_schema
    create_data_generator
    create_doc_generator
    create_rag_ingestion
    create_api
    create_ui
    create_env_template
    create_startup_script
    create_stop_script
    
    log "✅ Laika Dynamics VPS setup complete!"
    log ""
    log "🌍 READY FOR GLOBAL DEPLOYMENT!"
    log ""
    log "Next steps:"
    log "1. Run: ./start_rag_system.sh"
    log "2. Access from anywhere in the world:"
    log "   🌐 Web UI: http://$VPS_IP:$UI_PORT"
    log "   📡 API: http://$VPS_IP:$API_PORT"
    log "   🔍 Qdrant: http://$VPS_IP:$QDRANT_PORT/dashboard"
    log ""
    log "🚀 VPS Specifications:"
    log "- 2 vCPU cores, 8GB RAM"
    log "- 100GB NVMe storage"
    log "- 8TB bandwidth/month"
    log "- Global Hostinger network"
    log ""
    log "🤖 AI Features:"
    log "- Llama 3.1 8B model (4GB VRAM)"
    log "- BGE large embeddings"
    log "- 50K+ synthetic business records"
    log "- 10K+ generated documents"
    log "- SQLite + vector search"
    log ""
    log "⏱️ Estimated deployment time:"
    log "📊 Data generation: ~5 minutes"
    log "🧠 AI model download: ~10 minutes (first time)"
    log "🔍 Vector indexing: ~8 minutes"
    log ""
    log "🎯 Perfect for your AI dev team demo!"
    warn "💡 The system will be accessible globally - perfect for remote team demos!"
}

# Run main function
main "$@"