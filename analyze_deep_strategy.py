#!/usr/bin/env python3
"""
Análise PROFUNDA do EA Vertex_Logic
Identifica sinais falsos, entradas atrasadas, falta de sincronia.

FOCO: Por que o EA tem sinais falsos e não é lucrativo?
"""

import re
import pandas as pd
import numpy as np
from collections import defaultdict
from datetime import datetime

LOG_FILE = "20251217_utf8.log"

def extract_all_signals(log_file):
    """Extrai TODOS os sinais detectados e seu destino (executado ou rejeitado)."""
    signals = []
    trades = []
    rejections = defaultdict(int)
    
    # Padrões
    signal_pattern = re.compile(
        r'(\d{4}\.\d{2}\.\d{2}) (\d{2}:\d{2}:\d{2}).*Sinal detectado.*Entry=(-?\d+), Strength=(-?\d+), Confluence=([\d.]+)%'
    )
    
    trade_open_pattern = re.compile(
        r'(\d{4}\.\d{2}\.\d{2}) (\d{2}:\d{2}:\d{2}).*TRADE: (BUY|SELL) @ ([\d.]+).*SL: ([\d.]+).*TP: ([\d.]+)'
    )
    
    trade_close_pattern = re.compile(
        r'(\d{4}\.\d{2}\.\d{2}) (\d{2}:\d{2}:\d{2}).*TRADE CLOSED: (WIN|LOSS).*Profit: ([\-\d.]+)'
    )
    
    rejection_patterns = {
        'Passo1_Trend': re.compile(r'Passo 1.*Falhou'),
        'Passo2_RSIOMA': re.compile(r'Passo 2.*Falhou'),
        'Passo3_OBV': re.compile(r'Passo 3.*Falhou'),
        'RSIOMA_Block': re.compile(r'RSIOMA FILTRO:.*(bloqueado|Block)'),
        'OBV_Block': re.compile(r'OBV MACD:.*(REJEITADO|BLOQUEADO)'),
        'Confluence_Low': re.compile(r'Confluência.*insuficiente'),
        'Regime_Block': re.compile(r'(RANGING|VOLATILE).*bloqueado'),
    }
    
    alignment_pattern = re.compile(r'ALINHAMENTO PERFEITO')
    
    current_signal = None
    pending_trade = None
    
    with open(log_file, 'r', encoding='utf-8') as f:
        for line in f:
            # Detectar sinal
            sig_match = signal_pattern.search(line)
            if sig_match:
                current_signal = {
                    'date': sig_match.group(1),
                    'time': sig_match.group(2),
                    'entry': int(sig_match.group(3)),
                    'strength': int(sig_match.group(4)),
                    'confluence': float(sig_match.group(5)),
                    'executed': False,
                    'rejection_reason': None
                }
                signals.append(current_signal)
            
            # Detectar rejeição
            for reason, pattern in rejection_patterns.items():
                if pattern.search(line):
                    rejections[reason] += 1
                    if current_signal and not current_signal['executed']:
                        current_signal['rejection_reason'] = reason
            
            # Detectar alinhamento aprovado
            if alignment_pattern.search(line):
                if current_signal:
                    current_signal['executed'] = True
            
            # Detectar abertura de trade
            trade_match = trade_open_pattern.search(line)
            if trade_match:
                pending_trade = {
                    'open_date': trade_match.group(1),
                    'open_time': trade_match.group(2),
                    'direction': trade_match.group(3),
                    'entry_price': float(trade_match.group(4)),
                    'sl': float(trade_match.group(5)),
                    'tp': float(trade_match.group(6)),
                }
                if current_signal:
                    pending_trade['signal_strength'] = current_signal['strength']
                    pending_trade['signal_confluence'] = current_signal['confluence']
                    pending_trade['signal_entry'] = current_signal['entry']
            
            # Detectar fechamento de trade
            close_match = trade_close_pattern.search(line)
            if close_match and pending_trade:
                pending_trade['close_date'] = close_match.group(1)
                pending_trade['close_time'] = close_match.group(2)
                pending_trade['result'] = close_match.group(3)
                pending_trade['profit'] = float(close_match.group(4))
                trades.append(pending_trade)
                pending_trade = None
    
    return signals, trades, rejections

def analyze_signal_quality(signals, trades):
    """Analisa qualidade dos sinais vs resultados."""
    print("=" * 80)
    print("       ANÁLISE PROFUNDA DE QUALIDADE DE SINAIS")
    print("=" * 80)
    
    df_signals = pd.DataFrame(signals)
    df_trades = pd.DataFrame(trades)
    
    total_signals = len(df_signals)
    executed = df_signals[df_signals['executed'] == True]
    rejected = df_signals[df_signals['executed'] == False]
    
    print(f"\n📊 ESTATÍSTICAS DE SINAIS")
    print(f"   Total de sinais detectados: {total_signals}")
    print(f"   Sinais executados: {len(executed)} ({len(executed)/total_signals*100:.1f}%)")
    print(f"   Sinais rejeitados: {len(rejected)} ({len(rejected)/total_signals*100:.1f}%)")
    
    # Analisar por razão de rejeição
    print(f"\n🔍 RAZÕES DE REJEIÇÃO")
    if 'rejection_reason' in df_signals.columns:
        rejection_counts = df_signals[df_signals['rejection_reason'].notna()]['rejection_reason'].value_counts()
        for reason, count in rejection_counts.items():
            print(f"   {reason}: {count} ({count/len(rejected)*100:.1f}%)")
    
    # Analisar conflito Entry vs Strength
    print(f"\n⚠️ ANÁLISE DE CONFLITO ENTRY vs STRENGTH")
    
    # Entry = direção do sinal (1=BUY, -1=SELL)
    # Strength = força (positivo=bullish, negativo=bearish)
    # CONFLITO: Entry=1 (BUY) com Strength<0 (bearish) ou vice-versa
    
    conflicts = df_signals[
        ((df_signals['entry'] > 0) & (df_signals['strength'] < 0)) |
        ((df_signals['entry'] < 0) & (df_signals['strength'] > 0))
    ]
    aligned = df_signals[
        ((df_signals['entry'] > 0) & (df_signals['strength'] > 0)) |
        ((df_signals['entry'] < 0) & (df_signals['strength'] < 0))
    ]
    
    print(f"   Sinais com conflito Entry/Strength: {len(conflicts)} ({len(conflicts)/total_signals*100:.1f}%)")
    print(f"   Sinais alinhados Entry/Strength: {len(aligned)} ({len(aligned)/total_signals*100:.1f}%)")
    
    if len(conflicts) > 0:
        exec_conflicts = conflicts[conflicts['executed'] == True]
        print(f"   ⚠️ Conflitos que foram EXECUTADOS: {len(exec_conflicts)}")
    
    # Analisar trades
    print(f"\n📈 ANÁLISE DE TRADES EXECUTADOS")
    
    if len(df_trades) > 0:
        wins = df_trades[df_trades['result'] == 'WIN']
        losses = df_trades[df_trades['result'] == 'LOSS']
        
        print(f"   Total de trades: {len(df_trades)}")
        print(f"   Wins: {len(wins)} ({len(wins)/len(df_trades)*100:.1f}%)")
        print(f"   Losses: {len(losses)} ({len(losses)/len(df_trades)*100:.1f}%)")
        
        # Analisar por força de sinal
        if 'signal_strength' in df_trades.columns:
            print(f"\n   📊 Por Força de Sinal:")
            for strength in sorted(df_trades['signal_strength'].dropna().unique()):
                str_trades = df_trades[df_trades['signal_strength'] == strength]
                str_wins = str_trades[str_trades['result'] == 'WIN']
                if len(str_trades) > 0:
                    print(f"      F{abs(int(strength))}: {len(str_trades)} trades | WR: {len(str_wins)/len(str_trades)*100:.1f}%")
        
        # Analisar por confluência
        if 'signal_confluence' in df_trades.columns:
            print(f"\n   📊 Por Nível de Confluência:")
            df_trades['conf_bucket'] = pd.cut(df_trades['signal_confluence'], bins=[0, 50, 75, 90, 100], labels=['<50%', '50-75%', '75-90%', '90-100%'])
            for bucket in ['<50%', '50-75%', '75-90%', '90-100%']:
                bucket_trades = df_trades[df_trades['conf_bucket'] == bucket]
                bucket_wins = bucket_trades[bucket_trades['result'] == 'WIN']
                if len(bucket_trades) > 0:
                    print(f"      {bucket}: {len(bucket_trades)} trades | WR: {len(bucket_wins)/len(bucket_trades)*100:.1f}%")
    
    return df_signals, df_trades

def analyze_timing(trades):
    """Analisa timing das entradas."""
    print(f"\n⏱️ ANÁLISE DE TIMING")
    
    if len(trades) == 0:
        print("   Sem trades para analisar")
        return
    
    df = pd.DataFrame(trades)
    
    # Calcular duração dos trades
    if 'open_time' in df.columns and 'close_time' in df.columns:
        # Calcular SL e TP em pontos
        df['sl_distance'] = abs(df['entry_price'] - df['sl']) * 1000  # Em pips/pontos
        df['tp_distance'] = abs(df['tp'] - df['entry_price']) * 1000
        df['rr_ratio'] = df['tp_distance'] / df['sl_distance']
        
        print(f"\n   📊 Distâncias SL/TP:")
        print(f"      SL Médio: {df['sl_distance'].mean():.0f} pontos")
        print(f"      TP Médio: {df['tp_distance'].mean():.0f} pontos")
        print(f"      R:R Configurado: 1:{df['rr_ratio'].mean():.2f}")
        
        # Por resultado
        wins = df[df['result'] == 'WIN']
        losses = df[df['result'] == 'LOSS']
        
        print(f"\n   📈 Por Resultado:")
        if len(wins) > 0:
            print(f"      WINS - SL: {wins['sl_distance'].mean():.0f}pts | TP: {wins['tp_distance'].mean():.0f}pts")
        if len(losses) > 0:
            print(f"      LOSSES - SL: {losses['sl_distance'].mean():.0f}pts | TP: {losses['tp_distance'].mean():.0f}pts")

def suggest_improvements():
    """Sugestões de melhorias baseadas na análise."""
    print("\n" + "=" * 80)
    print("       🔧 DIAGNÓSTICO E CORREÇÕES RECOMENDADAS")
    print("=" * 80)
    
    print("""
🚨 PROBLEMA 1: CONFLITO ENTRY vs STRENGTH
==========================================
O indicador retorna:
- Entry = 1 (BUY) ou -1 (SELL) - direção do sinal
- Strength = 1 a 5 ou -1 a -5 - força E direção misturados

PROBLEMA: Entry=1 (BUY) com Strength=-3 significa:
- O sinal é de COMPRA (entry=1)
- Mas a força indica VENDA (strength negativo)
- Isso é um CONFLITO que gera sinais falsos!

📋 CORREÇÃO SUGERIDA:
Adicionar filtro para rejeitar sinais com conflito:
```mql5
// Em ProcessSignals():
if((entrySignal > 0 && signalStrength < 0) || 
   (entrySignal < 0 && signalStrength > 0))
{
    g_Stats.LogDebug("Sinal rejeitado: Conflito Entry/Strength");
    return;
}
```

🚨 PROBLEMA 2: FILTROS DEIXAM PASSAR SINAIS RUINS
=================================================
- 278 sinais detectados
- Apenas 24 executados (8.6%)
- Desses 24: apenas 4 wins (16.7% WR!)

O RSIOMA está BLOQUEANDO sinais bons e DEIXANDO PASSAR ruins!
Hipótese: O filtro RSIOMA está invertido ou mal calibrado.

📋 CORREÇÃO SUGERIDA:
Verificar lógica do RSIOMA:
- Para BUY: RSI deve estar ACIMA de 50 (momentum de alta)
- Para SELL: RSI deve estar ABAIXO de 50 (momentum de baixa)
- PORÉM: Se RSI > 80 para BUY = sobrecomprado = NÃO COMPRAR
- PORÉM: Se RSI < 20 para SELL = sobrevendido = NÃO VENDER

🚨 PROBLEMA 3: CONFLUÊNCIA NÃO CORRELACIONADA COM SUCESSO
==========================================================
- Trades com 100% confluência estão perdendo
- Trades com 75% confluência também perdem

A confluência mede COMPRESSÃO das EMAs, não QUALIDADE do sinal!

📋 CORREÇÃO SUGERIDA:
- Adicionar filtro de DIREÇÃO EMA200:
  - BUY apenas se preço > EMA200
  - SELL apenas se preço < EMA200
- Adicionar filtro de ATR para volatilidade:
  - Não operar se ATR muito baixo (mercado parado)
  - Não operar se ATR muito alto (mercado caótico)

🚨 PROBLEMA 4: R:R REAL vs CONFIGURADO
======================================
- R:R configurado: 1:2 (SL 250, TP 500)
- R:R real após BE/TS: 1:0.1 (cortando ganhos)

📋 JÁ CORRIGIDO ANTERIORMENTE (mas precisa validar)

🔧 IMPLEMENTAÇÃO PRIORITÁRIA:
==============================
1. Adicionar filtro de conflito Entry/Strength
2. Revisar lógica RSIOMA (pode estar invertida)
3. Adicionar filtro de direção EMA200 estrito
4. Testar com BE/TS DESATIVADOS primeiro
""")

def analyze_rsioma_performance(log_file):
    """Analisa performance do filtro RSIOMA."""
    print("\n" + "=" * 80)
    print("       🔬 ANÁLISE DETALHADA DO RSIOMA")
    print("=" * 80)
    
    rsioma_approved = []
    rsioma_blocked = []
    
    approved_pattern = re.compile(r'RSIOMA ESTADO: APROVADO \((\d+\.\d+) ([><]) (\d+\.\d+)\)')
    blocked_pattern = re.compile(r'RSIOMA FILTRO: (BUY|SELL) bloqueado.*RSI\(([\d.]+)\).*(\d+)')
    
    with open(log_file, 'r', encoding='utf-8') as f:
        for line in f:
            approved = approved_pattern.search(line)
            if approved:
                rsioma_approved.append({
                    'rsi': float(approved.group(1)),
                    'operator': approved.group(2),
                    'ma': float(approved.group(3))
                })
            
            blocked = blocked_pattern.search(line)
            if blocked:
                rsioma_blocked.append({
                    'direction': blocked.group(1),
                    'rsi': float(blocked.group(2)),
                    'threshold': int(blocked.group(3))
                })
    
    print(f"\n   RSIOMA Aprovados: {len(rsioma_approved)}")
    print(f"   RSIOMA Bloqueados: {len(rsioma_blocked)}")
    
    if rsioma_approved:
        rsi_values = [x['rsi'] for x in rsioma_approved]
        print(f"\n   RSI em sinais APROVADOS:")
        print(f"      Min: {min(rsi_values):.1f} | Max: {max(rsi_values):.1f} | Média: {np.mean(rsi_values):.1f}")
    
    if rsioma_blocked:
        blocked_buy = [x for x in rsioma_blocked if x['direction'] == 'BUY']
        blocked_sell = [x for x in rsioma_blocked if x['direction'] == 'SELL']
        print(f"\n   Bloqueios:")
        print(f"      BUYs bloqueados: {len(blocked_buy)}")
        print(f"      SELLs bloqueados: {len(blocked_sell)}")

def main():
    print("🔍 Iniciando análise profunda do EA...")
    
    try:
        signals, trades, rejections = extract_all_signals(LOG_FILE)
    except FileNotFoundError:
        print(f"❌ Arquivo {LOG_FILE} não encontrado!")
        return
    
    print(f"\n✅ Dados extraídos:")
    print(f"   Sinais: {len(signals)}")
    print(f"   Trades: {len(trades)}")
    
    # Análise de qualidade
    df_signals, df_trades = analyze_signal_quality(signals, trades)
    
    # Análise de timing
    analyze_timing(trades)
    
    # Análise RSIOMA
    analyze_rsioma_performance(LOG_FILE)
    
    # Sugestões
    suggest_improvements()
    
    print("\n" + "=" * 80)
    print("                    FIM DA ANÁLISE")
    print("=" * 80)

if __name__ == "__main__":
    main()
