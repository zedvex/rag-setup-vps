"""
CTGAN-based Synthetic Data Generator for Web Contracting Data
Generates realistic business data for RAG demo purposes
"""

import pandas as pd
import numpy as np
from faker import Faker
from ctgan import CTGAN
from datetime import datetime, timedelta
import random
import json
import os
from typing import List, Dict, Any

fake = Faker()

class WebContractDataGenerator:
    """Advanced synthetic data generator using CTGAN and Faker"""
    
    def __init__(self):
        self.fake = Faker()
        
        # Web development technologies
        self.tech_stacks = [
            "React, Node.js, MongoDB",
            "Vue.js, Express, PostgreSQL",
            "Angular, Django, MySQL",
            "Next.js, FastAPI, SQLite",
            "WordPress, PHP, MySQL",
            "Shopify, Liquid, JavaScript",
            "React Native, Firebase",
            "Flutter, Node.js, PostgreSQL",
            "Laravel, Vue.js, MySQL",
            "Django, React, PostgreSQL"
        ]
        
        # Contract types
        self.contract_types = [
            "website", "mobile_app", "ecommerce", "web_app", 
            "cms", "api_development", "maintenance", "redesign"
        ]
        
        # Industries
        self.industries = [
            "Technology", "Healthcare", "Finance", "Education", "Retail",
            "Manufacturing", "Real Estate", "Legal", "Consulting", "Non-profit",
            "Entertainment", "Food & Beverage", "Automotive", "Travel", "Fashion"
        ]
        
        # Project complexities
        self.complexities = ["simple", "medium", "complex", "enterprise"]
        
        # Payment terms
        self.payment_terms = [
            "Net 30", "Net 15", "50% upfront", "Weekly", "Monthly",
            "Upon completion", "Milestone-based", "Hourly"
        ]
        
        # Project statuses
        self.statuses = ["proposal", "active", "completed", "cancelled", "on_hold"]

    def generate_base_dataset(self, num_records: int = 1000) -> pd.DataFrame:
        """Generate base dataset using Faker for CTGAN training"""
        
        data = []
        
        for i in range(num_records):
            # Generate realistic contract data
            start_date = self.fake.date_between(start_date='-2y', end_date='today')
            estimated_completion = start_date + timedelta(days=random.randint(14, 365))
            
            # Calculate realistic pricing based on complexity and hours
            complexity = random.choice(self.complexities)
            base_hours = {
                "simple": random.randint(40, 120),
                "medium": random.randint(100, 300),
                "complex": random.randint(250, 600),
                "enterprise": random.randint(500, 1500)
            }[complexity]
            
            hourly_rate = random.uniform(50, 200)
            contract_value = base_hours * hourly_rate * random.uniform(0.8, 1.2)
            
            record = {
                'contract_id': f"WC-{self.fake.year()}-{str(i+1).zfill(4)}",
                'client_name': self.fake.name(),
                'client_email': self.fake.email(),
                'client_company': self.fake.company(),
                'contract_type': random.choice(self.contract_types),
                'project_title': self.generate_project_title(),
                'project_description': self.generate_project_description(),
                'project_scope': self.generate_project_scope(),
                'technologies': random.choice(self.tech_stacks),
                'contract_value': round(contract_value, 2),
                'hourly_rate': round(hourly_rate, 2),
                'estimated_hours': base_hours,
                'payment_terms': random.choice(self.payment_terms),
                'start_date': start_date,
                'estimated_completion': estimated_completion,
                'status': random.choice(self.statuses),
                'progress_percentage': random.uniform(0, 100) if random.choice([True, False]) else 0,
                'responsive_design': random.choice([True, False]),
                'cms_required': random.choice([True, False]),
                'ecommerce_features': random.choice([True, False]),
                'api_integration': random.choice([True, False]),
                'seo_optimization': random.choice([True, False]),
                'client_location': f"{self.fake.city()}, {self.fake.state()}",
                'client_industry': random.choice(self.industries),
                'project_complexity': complexity,
                'notes': self.generate_notes()
            }
            
            data.append(record)
        
        return pd.DataFrame(data)

    def generate_project_title(self) -> str:
        """Generate realistic project titles"""
        templates = [
            f"{self.fake.company()} Website Redesign",
            f"E-commerce Platform for {self.fake.company()}",
            f"Mobile App Development - {self.fake.catch_phrase()}",
            f"Custom Web Application for {self.fake.bs().title()}",
            f"WordPress Site for {self.fake.company()}",
            f"API Development and Integration",
            f"React Dashboard for {self.fake.company()}",
            f"Online Booking System",
            f"Corporate Website with CMS",
            f"Multi-vendor Marketplace Platform"
        ]
        return random.choice(templates)

    def generate_project_description(self) -> str:
        """Generate realistic project descriptions"""
        descriptions = [
            f"Develop a modern, responsive website that showcases {self.fake.bs()}. The site will feature clean design, fast loading times, and mobile optimization.",
            f"Create a comprehensive e-commerce solution with product catalog, shopping cart, payment integration, and admin dashboard for {self.fake.company()}.",
            f"Build a custom web application to streamline {self.fake.bs()} processes. Include user authentication, data visualization, and reporting features.",
            f"Design and develop a mobile-responsive platform that enables {self.fake.catch_phrase()}. Focus on user experience and performance optimization.",
            f"Implement a content management system allowing easy updates to website content, blog posts, and media galleries.",
        ]
        return random.choice(descriptions)

    def generate_project_scope(self) -> str:
        """Generate realistic project scope"""
        scopes = [
            "UI/UX design, frontend development, backend API, database design, testing, deployment, and 30-day post-launch support.",
            "Requirements analysis, wireframing, responsive design, CMS integration, SEO optimization, and performance testing.",
            "Custom functionality development, third-party integrations, user training, documentation, and ongoing maintenance.",
            "Mobile-first design, cross-browser compatibility, security implementation, and scalability considerations.",
            "Brand integration, content migration, payment gateway setup, inventory management, and analytics implementation."
        ]
        return random.choice(scopes)

    def generate_notes(self) -> str:
        """Generate realistic project notes"""
        notes = [
            "Client very responsive to communication. Project proceeding on schedule.",
            "Some scope changes requested. Updated timeline and budget accordingly.",
            "Excellent collaboration with client's internal team. Smooth development process.",
            "Additional features requested during development. Change order approved.",
            "Project completed successfully. Client expressed high satisfaction with results.",
            "Minor delays due to content delivery. Adjusted timeline as needed.",
            "Complex integration requirements. Required additional technical research.",
            "Client provided detailed feedback during review cycles. Iterative improvements made."
        ]
        return random.choice(notes) if random.random() > 0.3 else ""

    def train_ctgan_model(self, df: pd.DataFrame) -> CTGAN:
        """Train CTGAN model on the base dataset"""
        print("🤖 Training CTGAN model...")
        
        # Prepare data for CTGAN
        # Convert datetime columns to numeric for training
        df_train = df.copy()
        df_train['start_date_numeric'] = pd.to_datetime(df_train['start_date']).astype(int) / 10**9
        df_train['estimated_completion_numeric'] = pd.to_datetime(df_train['estimated_completion']).astype(int) / 10**9
        
        # Select numeric and categorical columns for training
        training_columns = [
            'contract_value', 'hourly_rate', 'estimated_hours', 'progress_percentage',
            'contract_type', 'client_industry', 'project_complexity', 'payment_terms', 'status',
            'responsive_design', 'cms_required', 'ecommerce_features', 'api_integration', 'seo_optimization',
            'start_date_numeric', 'estimated_completion_numeric'
        ]
        
        train_data = df_train[training_columns]
        
        # Initialize and train CTGAN
        ctgan = CTGAN(epochs=10)  # Reduced epochs for demo purposes
        ctgan.fit(train_data, discrete_columns=[
            'contract_type', 'client_industry', 'project_complexity', 'payment_terms', 'status',
            'responsive_design', 'cms_required', 'ecommerce_features', 'api_integration', 'seo_optimization'
        ])
        
        print("✅ CTGAN model training completed!")
        return ctgan

    def generate_synthetic_data(self, ctgan_model: CTGAN, num_samples: int = 500) -> pd.DataFrame:
        """Generate synthetic data using trained CTGAN model"""
        print(f"🎯 Generating {num_samples} synthetic records...")
        
        # Generate synthetic samples
        synthetic_data = ctgan_model.sample(num_samples)
        
        # Post-process the synthetic data
        df_synthetic = self.post_process_synthetic_data(synthetic_data)
        
        print("✅ Synthetic data generation completed!")
        return df_synthetic

    def post_process_synthetic_data(self, synthetic_df: pd.DataFrame) -> pd.DataFrame:
        """Clean and enhance synthetic data"""
        df = synthetic_df.copy()
        
        # Convert numeric dates back to datetime
        if 'start_date_numeric' in df.columns:
            df['start_date'] = pd.to_datetime(df['start_date_numeric'] * 10**9)
            df['estimated_completion'] = pd.to_datetime(df['estimated_completion_numeric'] * 10**9)
            df = df.drop(['start_date_numeric', 'estimated_completion_numeric'], axis=1)
        
        # Generate realistic text fields that CTGAN can't handle well
        for i in range(len(df)):
            df.loc[i, 'contract_id'] = f"WC-{fake.year()}-{str(i+1000).zfill(4)}"
            df.loc[i, 'client_name'] = fake.name()
            df.loc[i, 'client_email'] = fake.email()
            df.loc[i, 'client_company'] = fake.company()
            df.loc[i, 'project_title'] = self.generate_project_title()
            df.loc[i, 'project_description'] = self.generate_project_description()
            df.loc[i, 'project_scope'] = self.generate_project_scope()
            df.loc[i, 'technologies'] = random.choice(self.tech_stacks)
            df.loc[i, 'client_location'] = f"{fake.city()}, {fake.state()}"
            df.loc[i, 'notes'] = self.generate_notes()
        
        # Ensure data quality
        df['contract_value'] = df['contract_value'].abs()
        df['hourly_rate'] = df['hourly_rate'].abs()
        df['estimated_hours'] = df['estimated_hours'].abs().astype(int)
        df['progress_percentage'] = df['progress_percentage'].clip(0, 100)
        
        return df

    def generate_complete_dataset(self, base_size: int = 1000, synthetic_size: int = 2000) -> pd.DataFrame:
        """Generate complete dataset combining base and synthetic data"""
        print(f"🚀 Generating complete dataset: {base_size} base + {synthetic_size} synthetic records")
        
        # Step 1: Generate base dataset
        base_df = self.generate_base_dataset(base_size)
        print(f"✅ Generated {len(base_df)} base records")
        
        # Step 2: Train CTGAN model
        ctgan_model = self.train_ctgan_model(base_df)
        
        # Step 3: Generate synthetic data
        synthetic_df = self.generate_synthetic_data(ctgan_model, synthetic_size)
        print(f"✅ Generated {len(synthetic_df)} synthetic records")
        
        # Step 4: Combine datasets
        combined_df = pd.concat([base_df, synthetic_df], ignore_index=True)
        combined_df['data_source'] = ['base'] * len(base_df) + ['synthetic'] * len(synthetic_df)
        
        print(f"🎉 Complete dataset ready: {len(combined_df)} total records")
        return combined_df

    def save_dataset(self, df: pd.DataFrame, filename: str = None) -> str:
        """Save dataset to CSV file"""
        if filename is None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"web_contracts_dataset_{timestamp}.csv"
        
        filepath = os.path.join("data", filename)
        os.makedirs("data", exist_ok=True)
        
        df.to_csv(filepath, index=False)
        print(f"💾 Dataset saved to: {filepath}")
        return filepath

# Example usage and testing
if __name__ == "__main__":
    generator = WebContractDataGenerator()
    
    # Generate complete dataset
    dataset = generator.generate_complete_dataset(base_size=500, synthetic_size=1500)
    
    # Save dataset
    filepath = generator.save_dataset(dataset)
    
    # Display statistics
    print("\n📊 Dataset Statistics:")
    print(f"Total records: {len(dataset)}")
    print(f"Base records: {len(dataset[dataset['data_source'] == 'base'])}")
    print(f"Synthetic records: {len(dataset[dataset['data_source'] == 'synthetic'])}")
    print(f"Average contract value: ${dataset['contract_value'].mean():.2f}")
    print(f"Contract types: {dataset['contract_type'].value_counts().to_dict()}") 