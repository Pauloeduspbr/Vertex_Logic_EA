#!/usr/bin/env python3
"""
Análise Crítica Financeira do EA Vertex_Logic
Identifica por que o EA não dá lucro e quebra a conta.
"""

import re
import pandas as pd
import numpy as np
from collections import defaultdict
from datetime import datetime

# Configuração do arquivo de log
LOG_FILE = "20251217_utf8.log"

def parse_trades(log_file):
    """Extrai todos os trades do log."""
    trades = []
    
    # Padrões regex
    trade_closed_pattern = re.compile(
        r'\[(\d{2}:\d{2}:\d{2})\] \[INFO\] TRADE CLOSED: (WIN|LOSS) \| Profit: ([\-\d.]+) \| Razão: (.+)'
    )
    trade_open_pattern = re.compile(
        r'\[(\d{2}:\d{2}:\d{2})\] \[INFO\] TRADE: (BUY|SELL) @ ([\d.]+) \| Vol: ([\d.]+) \| SL: ([\d.]+) \| TP: ([\d.]+)'
    )
    be_pattern = re.compile(
        r'🎯 \[BE\] Break Even ATIVADO para (BUY|SELL) #(\d+)'
    )
    ts_start_pattern = re.compile(
        r'🚀 \[TS\] Trailing INICIADO para (BUY|SELL) #(\d+) \| Lucro: \+(\d+) steps'
    )
    ts_move_pattern = re.compile(
        r'📈 \[TS\] Trailing MOVEU (BUY|SELL) #(\d+) \| Novo SL: ([\d.]+) \(\+(\d+) steps protegidos\)'
    )
    date_pattern = re.compile(r'(\d{4}\.\d{2}\.\d{2})')
    
    current_date = None
    current_trade = {}
    be_activated = set()
    ts_activated = set()
    ts_moves = defaultdict(int)
    
    with open(log_file, 'r', encoding='utf-8') as f:
        for line in f:
            # Extrair data
            date_match = date_pattern.search(line)
            if date_match:
                current_date = date_match.group(1)
            
            # Detectar abertura de trade
            open_match = trade_open_pattern.search(line)
            if open_match:
                current_trade = {
                    'open_time': f"{current_date} {open_match.group(1)}",
                    'direction': open_match.group(2),
                    'entry': float(open_match.group(3)),
                    'volume': float(open_match.group(4)),
                    'sl': float(open_match.group(5)),
                    'tp': float(open_match.group(6))
                }
            
            # Detectar Break-Even
            be_match = be_pattern.search(line)
            if be_match:
                ticket = be_match.group(2)
                be_activated.add(ticket)
            
            # Detectar Trailing Start
            ts_match = ts_start_pattern.search(line)
            if ts_match:
                ticket = ts_match.group(2)
                ts_activated.add(ticket)
            
            # Contar movimentos de trailing
            ts_move_match = ts_move_pattern.search(line)
            if ts_move_match:
                ticket = ts_move_match.group(2)
                ts_moves[ticket] += 1
            
            # Detectar fechamento de trade
            close_match = trade_closed_pattern.search(line)
            if close_match:
                trade = {
                    'close_time': f"{current_date} {close_match.group(1)}",
                    'result': close_match.group(2),
                    'profit': float(close_match.group(3)),
                    'close_reason': close_match.group(4),
                    **current_trade
                }
                trades.append(trade)
                current_trade = {}
    
    return trades, be_activated, ts_activated, ts_moves

def analyze_trades(trades):
    """Análise financeira completa dos trades."""
    if not trades:
        print("❌ Nenhum trade encontrado no log!")
        return None
    
    df = pd.DataFrame(trades)
    
    print("=" * 80)
    print("             ANÁLISE CRÍTICA FINANCEIRA - VERTEX LOGIC EA")
    print("=" * 80)
    
    # Métricas Básicas
    total_trades = len(df)
    wins = df[df['result'] == 'WIN']
    losses = df[df['result'] == 'LOSS']
    
    win_count = len(wins)
    loss_count = len(losses)
    win_rate = (win_count / total_trades) * 100
    
    total_profit = df['profit'].sum()
    gross_profit = wins['profit'].sum()
    gross_loss = abs(losses['profit'].sum())
    
    avg_win = wins['profit'].mean() if len(wins) > 0 else 0
    avg_loss = abs(losses['profit'].mean()) if len(losses) > 0 else 0
    
    profit_factor = gross_profit / gross_loss if gross_loss > 0 else 0
    
    print(f"\n📊 MÉTRICAS GERAIS")
    print(f"   Total de Trades: {total_trades}")
    print(f"   Vitórias: {win_count} ({win_rate:.1f}%)")
    print(f"   Derrotas: {loss_count} ({100-win_rate:.1f}%)")
    print(f"   Lucro Total: ${total_profit:.2f}")
    print(f"   Profit Factor: {profit_factor:.2f}")
    
    print(f"\n💰 ANÁLISE DE RESULTADOS")
    print(f"   Lucro Bruto: ${gross_profit:.2f}")
    print(f"   Perda Bruta: ${gross_loss:.2f}")
    print(f"   Média Vitória: ${avg_win:.2f}")
    print(f"   Média Derrota: ${avg_loss:.2f}")
    print(f"   Relação R:R Real: 1:{avg_loss/avg_win:.1f}" if avg_win > 0 else "   R:R: N/A")
    
    # Análise por Razão de Fechamento
    print(f"\n🔍 ANÁLISE POR RAZÃO DE FECHAMENTO")
    by_reason = df.groupby('close_reason').agg({
        'profit': ['count', 'sum', 'mean'],
        'result': lambda x: (x == 'WIN').sum()
    }).round(2)
    print(by_reason.to_string())
    
    # Análise de Take Profit vs Stop Loss
    print(f"\n🎯 ANÁLISE CRÍTICA: TP vs SL")
    tp_trades = df[df['close_reason'] == 'Take Profit']
    sl_trades = df[df['close_reason'] == 'Stop Loss']
    
    tp_count = len(tp_trades)
    sl_count = len(sl_trades)
    
    print(f"   Trades fechados por TP: {tp_count} ({tp_count/total_trades*100:.1f}%)")
    print(f"   Trades fechados por SL: {sl_count} ({sl_count/total_trades*100:.1f}%)")
    
    if len(tp_trades) > 0:
        print(f"   Lucro médio em TP: ${tp_trades['profit'].mean():.2f}")
    if len(sl_trades) > 0:
        sl_wins = sl_trades[sl_trades['result'] == 'WIN']
        sl_losses = sl_trades[sl_trades['result'] == 'LOSS']
        print(f"   Wins por SL (BE/TS): {len(sl_wins)} → Média: ${sl_wins['profit'].mean():.2f}" if len(sl_wins) > 0 else "")
        print(f"   Losses por SL: {len(sl_losses)} → Média: ${sl_losses['profit'].mean():.2f}" if len(sl_losses) > 0 else "")
    
    # Distribuição de Lucros
    print(f"\n📈 DISTRIBUIÇÃO DE LUCROS (WINS)")
    if len(wins) > 0:
        wins_sorted = wins['profit'].sort_values()
        print(f"   Mínimo: ${wins_sorted.min():.2f}")
        print(f"   25%: ${wins_sorted.quantile(0.25):.2f}")
        print(f"   Mediana: ${wins_sorted.median():.2f}")
        print(f"   75%: ${wins_sorted.quantile(0.75):.2f}")
        print(f"   Máximo: ${wins_sorted.max():.2f}")
        
        # Contar wins pequenos (BE/TS) vs grandes (TP)
        small_wins = wins[wins['profit'] < 2.0]
        large_wins = wins[wins['profit'] >= 2.0]
        print(f"\n   Wins Pequenos (<$2, BE/TS): {len(small_wins)} ({len(small_wins)/len(wins)*100:.1f}%)")
        print(f"   Wins Grandes (>=$2, TP): {len(large_wins)} ({len(large_wins)/len(wins)*100:.1f}%)")
    
    # Expected Payoff
    expected_payoff = total_profit / total_trades
    print(f"\n📊 EXPECTED PAYOFF")
    print(f"   Por trade: ${expected_payoff:.2f}")
    
    # Kelly Criterion (quanto apostar)
    if avg_loss > 0 and avg_win > 0:
        win_prob = win_rate / 100
        loss_prob = 1 - win_prob
        b = avg_win / avg_loss  # b:1 odds
        kelly = (win_prob * b - loss_prob) / b
        print(f"\n📐 KELLY CRITERION")
        print(f"   Fração ótima: {kelly*100:.1f}%")
        if kelly < 0:
            print(f"   ⚠️ KELLY NEGATIVO = SISTEMA NÃO DEVE SER OPERADO!")
    
    # Drawdown
    cumulative = df['profit'].cumsum()
    rolling_max = cumulative.cummax()
    drawdown = rolling_max - cumulative
    max_dd = drawdown.max()
    
    print(f"\n📉 DRAWDOWN")
    print(f"   Máximo Drawdown: ${max_dd:.2f}")
    
    return df

def diagnose_problems(trades, be_activated, ts_activated, ts_moves):
    """Diagnóstico dos problemas identificados."""
    print("\n" + "=" * 80)
    print("              🚨 DIAGNÓSTICO DE PROBLEMAS")
    print("=" * 80)
    
    df = pd.DataFrame(trades)
    
    # Problema 1: Break-Even e Trailing cortando ganhos
    wins = df[df['result'] == 'WIN']
    tp_hits = df[df['close_reason'] == 'Take Profit']
    sl_wins = wins[wins['close_reason'] == 'Stop Loss']
    
    print("\n🔴 PROBLEMA 1: BREAK-EVEN E TRAILING CORTANDO GANHOS")
    print(f"   Total de Wins: {len(wins)}")
    print(f"   - Wins por TP (alvo atingido): {len(tp_hits)}")
    print(f"   - Wins por SL (BE/TS movido): {len(sl_wins)}")
    
    if len(wins) > 0:
        pct_cut = len(sl_wins) / len(wins) * 100
        print(f"   📊 {pct_cut:.1f}% dos WINS foram CORTADOS por BE/TS!")
    
    if len(sl_wins) > 0 and len(tp_hits) > 0:
        avg_sl_win = sl_wins['profit'].mean()
        avg_tp_win = tp_hits['profit'].mean()
        print(f"\n   💵 Média Win por SL (cortado): ${avg_sl_win:.2f}")
        print(f"   💰 Média Win por TP (cheio): ${avg_tp_win:.2f}")
        print(f"   📉 Perda de potencial: {(1 - avg_sl_win/avg_tp_win)*100:.1f}%")
    
    # Problema 2: Parâmetros Incompatíveis
    print("\n🔴 PROBLEMA 2: PARÂMETROS INCOMPATÍVEIS")
    print("""
   Configuração Atual (do log):
   - SL: 250-360 pontos (~3.60 USD de risco)
   - TP: 500-1000 pontos (~8.75 USD de alvo)
   - BE Trigger: 300 pontos (ANTES do TP!)
   - TS Trigger: 300 pontos (IGUAL ao BE!)
   - TS Distance: 100 pontos (muito próximo)
   
   🔥 DIAGNÓSTICO:
   1. BE ativa em 300pts, mas TP está em 500pts
      → Trade precisa andar mais 200pts após BE para TP
      → Qualquer retracement após BE = saída com lucro mínimo
   
   2. TS com distância de 100pts é muito apertado
      → Mercado normal tem volatilidade de 50-150pts
      → TS é acionado por ruído, não por reversão real
   
   3. Ambos (BE e TS) têm trigger de 300pts
      → Ativam simultaneamente
      → TS imediatamente começa a apertar o SL
   """)
    
    # Problema 3: Cálculo Matemático
    print("\n🔴 PROBLEMA 3: MATEMÁTICA CONTRA O EA")
    
    # Calcular lucro médio efetivo
    avg_win = df[df['result'] == 'WIN']['profit'].mean() if len(wins) > 0 else 0
    avg_loss = abs(df[df['result'] == 'LOSS']['profit'].mean()) if len(df[df['result'] == 'LOSS']) > 0 else 0
    win_rate = len(wins) / len(df) * 100
    
    print(f"""
   📊 REALIDADE ATUAL:
   - Win Rate: {win_rate:.1f}%
   - Média Win: ${avg_win:.2f}
   - Média Loss: ${avg_loss:.2f}
   - R:R Real: 1:{avg_loss/avg_win:.1f} (INVERTIDO!)
   
   📐 EXPECTATIVA MATEMÁTICA:
   E = (Win% × Avg Win) - (Loss% × Avg Loss)
   E = ({win_rate:.1f}% × ${avg_win:.2f}) - ({100-win_rate:.1f}% × ${avg_loss:.2f})
   E = ${(win_rate/100 * avg_win):.2f} - ${((100-win_rate)/100 * avg_loss):.2f}
   E = ${(win_rate/100 * avg_win) - ((100-win_rate)/100 * avg_loss):.2f} por trade
   
   ⚠️ PARA SER LUCRATIVO COM WIN RATE DE {win_rate:.1f}%:
   - Precisa R:R mínimo de 1:1 (Avg Win = Avg Loss)
   - Atualmente: Avg Win deveria ser ${avg_loss:.2f}, mas é ${avg_win:.2f}
   - Falta: ${avg_loss - avg_win:.2f} por win
   """)
    
    return None

def suggest_fixes():
    """Sugestões de correção."""
    print("\n" + "=" * 80)
    print("              ✅ CORREÇÕES RECOMENDADAS")
    print("=" * 80)
    
    print("""
   🔧 OPÇÃO 1: DESATIVAR BE/TS (mais simples)
   ----------------------------------------
   - Inp_UseBE = false
   - Inp_UseTrailing = false
   - Deixar trade correr até TP ou SL original
   - Resultado esperado: 52.8% WR × $8.75 - 47.2% × $3.60 = +$2.92/trade
   
   🔧 OPÇÃO 2: AJUSTAR PARÂMETROS BE/TS (recomendado)
   --------------------------------------------------
   - BE Trigger: 400pts (80% do TP de 500pts)
   - BE Offset: 50pts (lock 50pts de lucro)
   - TS Trigger: 500pts (ativa apenas após atingir TP zone)
   - TS Distance: 200pts (dar espaço para respirar)
   - TS Step: 50pts (movimentos graduais)
   
   🔧 OPÇÃO 3: PARCIAIS COM TS (avançado)
   --------------------------------------
   - Fechar 50% em TP1 = 250pts (1:1)
   - Mover SL para BE após TP1
   - Trailing no restante com distância de 150pts
   
   📌 PARÂMETROS SUGERIDOS (OPÇÃO 2):
   
   //--- Break-Even
   input int      Inp_BE_Trigger      = 400;    // 80% do TP
   input int      Inp_BE_Offset       = 50;     // Lucro mínimo garantido
   
   //--- Trailing Stop  
   input int      Inp_Trail_Trigger   = 500;    // Apenas após atingir TP zone
   input int      Inp_Trail_Distance  = 200;    // Espaço para volatilidade
   input int      Inp_Trail_Step      = 50;     // Movimentos suaves
   """)

def main():
    print("Carregando log de trades...")
    
    try:
        trades, be_activated, ts_activated, ts_moves = parse_trades(LOG_FILE)
    except FileNotFoundError:
        print(f"❌ Arquivo {LOG_FILE} não encontrado!")
        return
    
    if not trades:
        print("❌ Nenhum trade encontrado no log!")
        return
    
    print(f"✅ {len(trades)} trades encontrados")
    print(f"✅ {len(be_activated)} ativações de BE detectadas")
    print(f"✅ {len(ts_activated)} ativações de TS detectadas")
    print(f"✅ {sum(ts_moves.values())} movimentos de TS detectados")
    
    # Análise principal
    df = analyze_trades(trades)
    
    # Diagnóstico
    diagnose_problems(trades, be_activated, ts_activated, ts_moves)
    
    # Sugestões
    suggest_fixes()
    
    print("\n" + "=" * 80)
    print("                    FIM DA ANÁLISE")
    print("=" * 80)

if __name__ == "__main__":
    main()
