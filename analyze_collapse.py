import re
import sys
from datetime import datetime

def parse_logs(file_path):
    try:
        with open(file_path, 'r', encoding='utf-16') as f:
            lines = f.readlines()
    except UnicodeError:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()
        except:
            with open(file_path, 'r', encoding='latin-1') as f:
                lines = f.readlines()

    # Regex patterns
    # 2023.01.26 04:00:00 [INFO] Sinal detectado! Bar=1, Entry=-1, Strength=-3, Confluence=50.0%
    signal_regex = r"(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}).*Sinal detectado!.*Entry=([-\d]+).*Strength=([-\d]+)"
    
    # 2023.01.26 06:15:00 [INFO] Posição fechada - Lucro: -18.32 | Razão: Stop Loss
    close_regex = r"(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}).*Posição fechada - Lucro:\s*([\d\.\-]+)\s*\|\s*Razão:\s*(.+)"

    collapse_start = datetime.strptime("2023.01.26", "%Y.%m.%d")
    
    signals = []
    trades = []

    print(f"ANÁLISE DE COLAPSO (Pós {collapse_start})")
    print("="*60)
    print(f"{'DATA':<20} | {'TIPO':<10} | {'DETALHES':<30}")
    print("-" * 60)

    for line in lines:
        # Extract Timestamp
        # Assuming timestamp is always at index 0-19 in the line part after the core info
        # But looking at the log format: "Tag 0 Time Core Date Time Msg"
        # We'll use regex to grab the first date-time occurrence
        
        timestamp_match = re.search(r"\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}", line)
        if not timestamp_match:
            continue
            
        current_dt_str = timestamp_match.group(0)
        current_dt = datetime.strptime(current_dt_str, "%Y.%m.%d %H:%M:%S")
        
        if current_dt < collapse_start:
            continue

        # Check for Signal
        sig_match = re.search(signal_regex, line)
        if sig_match:
            entry_dir = int(sig_match.group(2))
            strength = int(sig_match.group(3))
            direction = "BUY" if entry_dir == 1 else "SELL" if entry_dir == -1 else "NONE"
            print(f"{current_dt_str} | SIGNAL     | {direction} (Str: {strength})")
            continue

        # Check for Close
        close_match = re.search(close_regex, line)
        if close_match:
            profit = float(close_match.group(2))
            reason = close_match.group(3)
            result = "WIN" if profit > 0 else "LOSS"
            print(f"{current_dt_str} | {result:<8} | Profit: {profit:>6.2f} [{reason}]")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        parse_logs(sys.argv[1])
    else:
        parse_logs("20251215.log")
