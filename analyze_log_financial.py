
import re
import pandas as pd
import sys

log_file_path = '/media/nexustecnologies/Documentos/EA_Projetos/Vertex_Logic_EA/Vertex_Logic_EA/20251217.log'

def parse_mt5_log(file_path):
    deals = []
    
    try:
        with open(file_path, 'r', encoding='utf-16') as f:
            lines = f.readlines()
    except UnicodeError:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except Exception as e:
        print(f"Error reading file: {e}")
        return pd.DataFrame()

    # Regex to capture deal information
    # Example: 2025.12.17 00:00:00   deal #2  sell 1.00 USDJPY at 145.000 done (based on order #2)
    # Example: 2025.12.17 00:00:00   deal #3  buy 1.00 USDJPY at 144.500 done (based on order #3)
    # Note: The log format depends heavily on how the tester outputs it. 
    # Often for profit we look for lines like:
    # "profit: 100.00" or similar, OR we calculate from open/close prices if available in a consistent "deal" block.
    # However, standard tester logs usually record entries and exits.
    # A better approach for "profit" from logs is looking for "profit" keyword related to close deals.
    
    # Let's search for "profit" or "loss" lines or close deals.
    # Expected format for closed deal often involves "profit: x.xx"
    
    parsed_data = []
    
    for line in lines:
        if "profit:" in line.lower() or "deal" in line.lower():
            parsed_data.append(line.strip())
            
    return parsed_data

def analyze_financials(lines):
    profits = []
    
    # We'll look for lines that explicitly mention profit, or try to infer it.
    # Standard MT5 tester log for a closed trade:
    # ... deal #... sell ... done ... profit: 50.00
    
    profit_pattern = re.compile(r'profit:\s*([\d\.-]+)')
    
    for line in lines:
        match = profit_pattern.search(line)
        if match:
            try:
                p = float(match.group(1))
                profits.append(p)
            except ValueError:
                pass
                
    if not profits:
        print("No profit data found in logs using standard patterns. Searching for custom EA log patterns...")
        # Fallback: Look for custom EA logs if they log profit
        # Example: "Trade Closed: Profit=..."
        return
        
    df = pd.DataFrame({'profit': profits})
    
    total_trades = len(df)
    gross_profit = df[df['profit'] > 0]['profit'].sum()
    gross_loss = abs(df[df['profit'] < 0]['profit'].sum())
    net_profit = df['profit'].sum()
    
    wins = df[df['profit'] > 0]
    losses = df[df['profit'] < 0]
    
    win_rate = (len(wins) / total_trades * 100) if total_trades > 0 else 0
    profit_factor = (gross_profit / gross_loss) if gross_loss > 0 else float('inf')
    
    avg_win = wins['profit'].mean() if not wins.empty else 0
    avg_loss = losses['profit'].mean() if not losses.empty else 0
    
    print("="*40)
    print("FINANCIAL ANALYSIS REPORT")
    print("="*40)
    print(f"Total Trades: {total_trades}")
    print(f"Net Profit:   {net_profit:.2f}")
    print(f"Gross Profit: {gross_profit:.2f}")
    print(f"Gross Loss:   {gross_loss:.2f}")
    print(f"Profit Factor: {profit_factor:.2f}")
    print(f"Win Rate:     {win_rate:.2f}%")
    print(f"Avg Win:      {avg_win:.2f}")
    print(f"Avg Loss:     {avg_loss:.2f}")
    print("="*40)
    
    # Advanced: Sequence analysis (consecutive losses) or Drawdown
    df['cumulative_profit'] = df['profit'].cumsum()
    df['peak'] = df['cumulative_profit'].cummax()
    df['drawdown'] = df['peak'] - df['cumulative_profit']
    max_drawdown = df['drawdown'].max()
    
    print(f"Max Drawdown ($): {max_drawdown:.2f}")
    print("="*40)

raw_lines = parse_mt5_log(log_file_path)
print(f"Extracted {len(raw_lines)} relevant lines.")
if len(raw_lines) > 0:
    print("Sample lines:")
    for l in raw_lines[:5]:
        print(l)
        
analyze_financials(raw_lines)
