
import re
import pandas as pd
import sys

log_file_path = '/media/nexustecnologies/Documentos/EA_Projetos/Vertex_Logic_EA/Vertex_Logic_EA/20251217.log'

def parse_mt5_log(file_path):
    try:
        with open(file_path, 'r', encoding='utf-16') as f:
            lines = f.readlines()
    except UnicodeError:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()
        except:
            return []

    # Filter relevant lines to speed up processing
    relevant_lines = [line.strip() for line in lines if "TRADE CLOSED" in line or "deal #" in line]
    return relevant_lines

def analyze_financials(lines):
    profits = []
    
    # Regex for the custom log format seen:
    # ... [INFO] TRADE CLOSED: WIN | Profit: 0.10 | Razão: ...
    # ... [INFO] TRADE CLOSED: LOSS | Profit: -5.20 | Razão: ...
    
    custom_profit_pattern = re.compile(r'Profit:\s*([\d\.-]+)', re.IGNORECASE)
    
    for line in lines:
        if "TRADE CLOSED" in line:
            match = custom_profit_pattern.search(line)
            if match:
                try:
                    p = float(match.group(1))
                    profits.append(p)
                except ValueError:
                    pass
    
    if not profits:
        print("Still no profit data found. Let's dump some lines to debug.")
        for l in lines[:10]:
            print(l)
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
    
    # Expected Value = (Win% * AvgWin) - (Loss% * AvgLoss) (AvgLoss is negative usually, so + (-Loss))
    # Or just Total Net Profit / Total Trades
    expected_payoff = net_profit / total_trades if total_trades > 0 else 0

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
    print(f"Exp Payoff:   {expected_payoff:.2f}")
    print("="*40)
    
    # Consecutive Losses analysis
    consecutive_losses = 0
    max_consecutive_losses = 0
    current_cons = 0
    
    for p in profits:
        if p < 0:
            current_cons += 1
        else:
            if current_cons > max_consecutive_losses:
                max_consecutive_losses = current_cons
            current_cons = 0
    if current_cons > max_consecutive_losses:
        max_consecutive_losses = current_cons
        
    print(f"Max Consecutive Losses: {max_consecutive_losses}")

    # Drawdown
    df['cumulative_profit'] = df['profit'].cumsum()
    df['peak'] = df['cumulative_profit'].cummax()
    df['drawdown'] = df['peak'] - df['cumulative_profit']
    max_drawdown = df['drawdown'].max()
    
    print(f"Max Drawdown ($): {max_drawdown:.2f}")
    print("="*40)

raw_lines = parse_mt5_log(log_file_path)
analyze_financials(raw_lines)
