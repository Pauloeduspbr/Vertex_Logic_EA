import re
import pandas as pd
import numpy as np
import sys
import datetime

LOG_FILE = "/media/nexustecnologies/Documentos/EA_Projetos/Vertex_Logic_EA/Vertex_Logic_EA/20251215.log"

def parse_log(file_path):
    deals = []
    
    # Regex for deal execution
    # Example: deal #2 buy 0.01 USDJPY at 130.885 done (based on order #2)
    deal_pattern = re.compile(r"(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})\s+deal #(\d+) (buy|sell) ([\d.]+) (\w+) at ([\d.]+)")
    
    try:
        with open(file_path, 'r', encoding='utf-16le') as f:
            for line in f:
                match = deal_pattern.search(line)
                if match:
                    timestamp_str, deal_id, direction, volume, symbol, price = match.groups()
                    dt = datetime.datetime.strptime(timestamp_str, "%Y.%m.%d %H:%M:%S")
                    deals.append({
                        'time': dt,
                        'deal_id': deal_id,
                        'type': direction,
                        'volume': float(volume),
                        'symbol': symbol,
                        'price': float(price)
                    })
    except Exception as e:
        print(f"Error reading file: {e}")
        return pd.DataFrame()

    return pd.DataFrame(deals)

def analyze_trades(deals_df):
    if deals_df.empty:
        print("No deals found.")
        return

    trades = []
    
    # Simple FIFO matching for single-position strategy
    # This assumes the EA doesn't hedge or grid significantly
    # Logic: Buy opens, Sell closes (or vice versa)
    
    open_position = None
    
    for i, row in deals_df.iterrows():
        if open_position is None:
            open_position = row
        else:
            # Check if this closes the position
            # If opposite type, it's a close
            if row['type'] != open_position['type']:
                entry_price = open_position['price']
                exit_price = row['price']
                volume = open_position['volume']
                symbol = row['symbol']
                
                if open_position['type'] == 'buy':
                    profit_price_diff = exit_price - entry_price
                else: # sell
                    profit_price_diff = entry_price - exit_price
                
                # Approximate profit (Symbol generic)
                # Assuming USDJPY or similar where 0.01 is a pip? No, JPY pip is 0.01.
                # Just report price diff for now.
                
                duration = row['time'] - open_position['time']
                
                trades.append({
                    'entry_time': open_position['time'],
                    'exit_time': row['time'],
                    'type': open_position['type'],
                    'entry_price': entry_price,
                    'exit_price': exit_price,
                    'price_diff': profit_price_diff,
                    'duration': duration,
                    'symbol': symbol
                })
                open_position = None
            else:
                # Same direction? Averaging? Not handled in simple model.
                # Reset for now to avoid confusion or treat as new leg?
                print(f"Warning: Consecutive {row['type']} at {row['time']}. Strategy might be averaging.")
                open_position = row # Treat as new base?
                
    trades_df = pd.DataFrame(trades)
    return trades_df

def print_stats(trades_df):
    if trades_df.empty:
        print("No complete trades formed.")
        return

    print("--- ANALYSIS REPORT ---")
    total_trades = len(trades_df)
    winning_trades = trades_df[trades_df['price_diff'] > 0]
    losing_trades = trades_df[trades_df['price_diff'] <= 0]
    
    win_rate = len(winning_trades) / total_trades * 100
    
    avg_win = winning_trades['price_diff'].mean() if not winning_trades.empty else 0
    avg_loss = losing_trades['price_diff'].mean() if not losing_trades.empty else 0
    
    gross_profit = winning_trades['price_diff'].sum()
    gross_loss = abs(losing_trades['price_diff'].sum())
    
    profit_factor = gross_profit / gross_loss if gross_loss != 0 else float('inf')
    
    print(f"Total Trades: {total_trades}")
    print(f"Win Rate: {win_rate:.2f}%")
    print(f"Profit Factor: {profit_factor:.2f}")
    print(f"Avg Win (Price Diff): {avg_win:.5f}")
    print(f"Avg Loss (Price Diff): {avg_loss:.5f}")
    
    # Drawdown Analysis (Cumulative Price Diff)
    trades_df['cum_profit'] = trades_df['price_diff'].cumsum()
    trades_df['peak'] = trades_df['cum_profit'].cummax()
    trades_df['drawdown'] = trades_df['peak'] - trades_df['cum_profit']
    max_dd = trades_df['drawdown'].max()
    
    print(f"Max Drawdown (Price Diff): {max_dd:.5f}")
    
    # Duration Analysis
    avg_duration = trades_df['duration'].mean()
    print(f"Avg Trade Duration: {avg_duration}")
    
    print("\n--- RECENT LOSING STREAKS ---")
    # Identify streaks
    # ...

def main():
    print("Reading log file...")
    deals_df = parse_log(LOG_FILE)
    print(f"Parsed {len(deals_df)} deals.")
    
    trades_df = analyze_trades(deals_df)
    
    if trades_df is not None:
        print_stats(trades_df)
        
        # Save to CSV for user inspection
        output_csv = "trades_analysis.csv"
        trades_df.to_csv(output_csv, index=False)
        print(f"\nDetailed trade list saved to {output_csv}")

if __name__ == "__main__":
    main()
