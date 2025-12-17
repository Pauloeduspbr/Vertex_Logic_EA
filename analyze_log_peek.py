
import pandas as pd
import re
import sys

log_file_path = '/media/nexustecnologies/Documentos/EA_Projetos/Vertex_Logic_EA/Vertex_Logic_EA/20251217.log'

try:
    with open(log_file_path, 'r', encoding='utf-16') as f:
        content = f.readlines()
except UnicodeError:
    try:
        with open(log_file_path, 'r', encoding='utf-8') as f:
            content = f.readlines()
    except Exception as e:
        print(f"Error reading file: {e}")
        sys.exit(1)

# Basic parsing simulation (adjust regex based on actual log format)
# Assuming typical MT5 log format: "Time   Message"
data = []
for line in content:
    line = line.strip()
    if not line: continue
    
    # Try to extract common fields
    # Example: 2025.12.17 00:00:00   failed to load...
    parts = line.split('\t')
    if len(parts) < 2:
        parts = line.split('   ') # Try 3 spaces
        
    if len(parts) >= 2:
        data.append({'full_line': line})

print(f"Read {len(data)} lines.")
if len(data) > 0:
    for i in range(min(20, len(data))):
        print(data[i]['full_line'])

