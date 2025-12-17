import re
from collections import Counter

def analyze_rejections(file_path):
    try:
        with open(file_path, 'r', encoding='utf-16') as f:
            content = f.read()
    except:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
        except Exception as e:
            print(f"Error: {e}")
            return

    # Count "FILTRO BLOQUEOU" messages
    bloqueios = re.findall(r"FILTRO BLOQUEOU: (.*)", content)
    
    print(f"Total de Sinais Bloqueados: {len(bloqueios)}")
    
    counter = Counter(bloqueios)
    print("\n--- Top Rejection Reasons ---")
    for reason, count in counter.most_common(10):
        print(f"{count}x : {reason}")

    # Count "ALINHAMENTO PERFEITO" (Trades Executed)
    trades = len(re.findall(r"ALINHAMENTO PERFEITO", content))
    print(f"\nTotal de Trades Executados: {trades}")
    
    if trades > 0:
        ratio = len(bloqueios) / trades
        print(f"Ratio Bloqueio/Trade: {ratio:.1f} (Para cada 1 trade, {ratio:.0f} são bloqueados)")

if __name__ == "__main__":
    analyze_rejections("/media/nexustecnologies/Documentos/EA_Projetos/Vertex_Logic_EA/Vertex_Logic_EA/20251216.log")
