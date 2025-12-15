import re
import sys

def analyze_log(file_path):
    try:
        # Tenta ler com UTF-16 (padrão MT5 log)
        with open(file_path, 'r', encoding='utf-16') as f:
            content = f.read()
    except UnicodeError:
        # Fallback para UTF-8 ou Latin-1 se falhar
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
        except:
            print("Erro de encoding. Tentando latin-1.")
            with open(file_path, 'r', encoding='latin-1') as f:
                content = f.read()

    # Regex para capturar lucro e razão
    # Posição fechada - Lucro: 0.36 | Razão: Stop Loss
    regex = r"Posição fechada - Lucro:\s*([\d\.\-]+)\s*\|\s*Razão:\s*(.+)"
    
    trades = []
    
    for line in content.splitlines():
        match = re.search(regex, line)
        if match:
            profit = float(match.group(1))
            reason = match.group(2).strip()
            trades.append({'profit': profit, 'reason': reason})

    if not trades:
        print("Nenhum trade encontrado no log.")
        return

    total_trades = len(trades)
    gross_profit = sum(t['profit'] for t in trades if t['profit'] > 0)
    gross_loss = abs(sum(t['profit'] for t in trades if t['profit'] < 0))
    net_profit = gross_profit - gross_loss
    
    wins = [t for t in trades if t['profit'] > 0]
    losses = [t for t in trades if t['profit'] < 0]
    
    num_wins = len(wins)
    num_losses = len(losses)
    win_rate = (num_wins / total_trades * 100) if total_trades > 0 else 0
    
    avg_win = (gross_profit / num_wins) if num_wins > 0 else 0
    avg_loss = (gross_loss / num_losses) if num_losses > 0 else 0
    profit_factor = (gross_profit / gross_loss) if gross_loss > 0 else float('inf')
    
    # Calculate Drawdown
    balance = 0
    peak = 0
    max_drawdown = 0
    
    for t in trades:
        balance += t['profit']
        if balance > peak:
            peak = balance
        dd = peak - balance
        if dd > max_drawdown:
            max_drawdown = dd

    print(f"ANÁLISE DE LOG: {file_path}")
    print("="*40)
    print(f"Total Trades: {total_trades}")
    print(f"Wins: {num_wins} ({win_rate:.2f}%)")
    print(f"Losses: {num_losses}")
    print("-" * 20)
    print(f"Gross Profit: {gross_profit:.2f}")
    print(f"Gross Loss:   {gross_loss:.2f}")
    print(f"Net Profit:   {net_profit:.2f}")
    print("-" * 20)
    print(f"Profit Factor: {profit_factor:.2f}")
    print(f"Avg Win:       {avg_win:.2f}")
    print(f"Avg Loss:      {avg_loss:.2f}")
    print(f"Max Drawdown:  {max_drawdown:.2f}")
    print("="*40)
    
    # Análise de Razões
    print("Por Razão de Saída:")
    reasons = {}
    for t in trades:
        r = t['reason']
        if r not in reasons:
            reasons[r] = {'count': 0, 'profit': 0}
        reasons[r]['count'] += 1
        reasons[r]['profit'] += t['profit']
        
    for r, data in reasons.items():
        print(f"  {r}: {data['count']} trades | Lucro Total: {data['profit']:.2f}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python analyze_logs.py <arquivo_log>")
    else:
        analyze_log(sys.argv[1])
