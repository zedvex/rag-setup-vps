#!/usr/bin/env python3
"""
Hotfix for OpenAI embedding model compatibility issue
This replaces the set_openai_key method to use compatible models
"""

import os
import sys

# The fixed set_openai_key method code
FIXED_SET_OPENAI_KEY = '''    def set_openai_key(self, api_key: str):
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
            return False'''

def apply_hotfix():
    api_file = "/root/laika-dynamics-rag/api/main.py"
    
    if not os.path.exists(api_file):
        print(f"❌ API file not found: {api_file}")
        return False
    
    # Read the current file
    with open(api_file, 'r') as f:
        content = f.read()
    
    # Find and replace the set_openai_key method
    start_marker = "    def set_openai_key(self, api_key: str):"
    end_marker = "            return False"
    
    start_idx = content.find(start_marker)
    if start_idx == -1:
        print("❌ Could not find set_openai_key method")
        return False
    
    # Find the end of the method (look for the return False after the except block)
    end_idx = content.find(end_marker, start_idx)
    if end_idx == -1:
        print("❌ Could not find end of set_openai_key method")
        return False
    
    # Find the actual end (include the return False line)
    end_idx = content.find('\n', end_idx) + 1
    
    # Replace the method
    new_content = content[:start_idx] + FIXED_SET_OPENAI_KEY + content[end_idx:]
    
    # Backup original
    backup_file = api_file + ".backup"
    with open(backup_file, 'w') as f:
        f.write(content)
    print(f"✅ Backup created: {backup_file}")
    
    # Write the fixed version
    with open(api_file, 'w') as f:
        f.write(new_content)
    print(f"✅ Hotfix applied to: {api_file}")
    
    return True

if __name__ == "__main__":
    if apply_hotfix():
        print("\n🎯 Hotfix applied successfully!")
        print("Now restart the API server:")
        print("cd /root/laika-dynamics-rag && ./stop.sh && ./start.sh")
    else:
        print("\n❌ Hotfix failed!")
        sys.exit(1) 