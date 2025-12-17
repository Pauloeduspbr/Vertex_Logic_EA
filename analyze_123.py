import re
from collections import Counter

def analyze_123_failures(file_path):
    try:
        with open(file_path, 'r', encoding='utf-16') as f:
            lines = f.readlines()
    except:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()
        except Exception as e:
            print(f"Error: {e}")
            return

    steps_failed = []
    
    # Iterate through lines and look for "STRATEGY 1-2-3: Passo X ... Falhou"
    for line in lines:
        if "STRATEGY 1-2-3" in line and "Falhou" in line:
            # Extract step name
            match = re.search(r"Passo (\d+)", line)
            if match:
                steps_failed.append(f"Passo {match.group(1)}")

    print(f"Total de Falhas Específicas 1-2-3: {len(steps_failed)}")
    
    counter = Counter(steps_failed)
    print("\n--- 1-2-3 Failure Breakdown ---")
    for step, count in counter.most_common():
        percentage = (count / len(steps_failed) * 100) if steps_failed else 0
        print(f"{step}: {count} ({percentage:.1f}%)")

if __name__ == "__main__":
    analyze_123_failures("/media/nexustecnologies/Documentos/EA_Projetos/Vertex_Logic_EA/Vertex_Logic_EA/20251216.log")
