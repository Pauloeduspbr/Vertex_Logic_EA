import os

def analyze_log(file_path):
    if not os.path.exists(file_path):
        print(f"File not found: {file_path}")
        return

    try:
        # Try BOM if exists, or UTF-16LE
        with open(file_path, 'r', encoding='utf-16') as f:
            lines = f.readlines()
    except UnicodeError:
        try:
             with open(file_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()
        except Exception as e:
            print(f"Error reading file: {e}")
            return
    except Exception as e:
        print(f"Error reading file: {e}")
        return

    print(f"Total lines: {len(lines)}")
    
    # Filter for relevant lines
    keywords = ["Profit", "Sl", "Tp", "Order", "Deal", "Position", "Sinal", "Strategy", "FILTER", "FGM", "1-2-3"]
    
    relevant_lines = []
    for i, line in enumerate(lines):
        if any(k.lower() in line.lower() for k in keywords):
            relevant_lines.append(f"{i+1}: {line.strip()}")
            
    # Print last 50 relevant lines
    print("\n--- Last 50 Relevant Log Lines ---")
    for line in relevant_lines[-50:]:
        print(line)

if __name__ == "__main__":
    analyze_log("/media/nexustecnologies/Documentos/EA_Projetos/Vertex_Logic_EA/Vertex_Logic_EA/20251216.log")
