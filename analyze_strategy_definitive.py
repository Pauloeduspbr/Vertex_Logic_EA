#!/usr/bin/env python3
"""
ANÁLISE ESTRATÉGICA DEFINITIVA - EA VERTEX_LOGIC
================================================
Objetivo: Identificar o padrão EXATO que gera trades vencedores vs perdedores
e criar uma estratégia matematicamente lucrativa.

Autor: Análise Python para desenvolvimento de EA
"""

import re
import pandas as pd
import numpy as np
from collections import defaultdict
from datetime import datetime, timedelta

LOG_FILE = "20251217_utf8.log"

def parse_complete_log(log_file):
    """
    Extrai TODOS os dados relevantes do log:
    - Sinais detectados (com Entry, Strength, Confluence)
    - Condições de filtros (RSIOMA, OBV, VWAP, EMA)
    - Trades executados
    - Resultados (WIN/LOSS com profit/loss)
    """
    
    all_signals = []
    all_trades = []
    current_signal = None
    current_trade = None
    
    # Padrões regex
    patterns = {
        'signal': re.compile(
            r'(\d{4}\.\d{2}\.\d{2})\s+(\d{2}:\d{2}:\d{2}).*Sinal detectado.*Entry=(-?\d+).*Strength=(-?\d+).*Confluence=([\d.]+)%'
        ),
        'trend_ok': re.compile(r'PASSO 1:.*CONFIRMADA.*Close[=>< ]+([\d.]+)'),
        'rsioma_approved': re.compile(r'RSIOMA ESTADO: APROVADO.*\(([\d.]+)\s*[><]\s*([\d.]+)\)'),
        'rsioma_rejected': re.compile(r'RSIOMA STATUS: REPROVADO.*\[(BUY|SELL)\]'),
        'obv_approved': re.compile(r'OBV MACD:.*APROVADO'),
        'obv_rejected': re.compile(r'OBV MACD STATUS: REPROVADO'),
        'obv_hist': re.compile(r'\[OBV MACD DEBUG\].*Hist=([\-\d.]+).*Color=(\d+)'),
        'conflict': re.compile(r'SINAL REJEITADO: Conflito Entry/Strength'),
        'trade_open': re.compile(
            r'(\d{4}\.\d{2}\.\d{2})\s+(\d{2}:\d{2}:\d{2}).*TRADE: (BUY|SELL) @ ([\d.]+).*SL: ([\d.]+).*TP: ([\d.]+)'
        ),
        'trade_close': re.compile(
            r'(\d{4}\.\d{2}\.\d{2})\s+(\d{2}:\d{2}:\d{2}).*TRADE CLOSED: (WIN|LOSS).*Profit: ([\-\d.]+).*Razão: (.*)'
        ),
        'be_activated': re.compile(r'Break Even ATIVADO'),
        'trailing': re.compile(r'Trailing.*modificado'),
    }
    
    signal_count = 0
    
    with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            # Novo sinal detectado
            sig_match = patterns['signal'].search(line)
            if sig_match:
                signal_count += 1
                current_signal = {
                    'id': signal_count,
                    'date': sig_match.group(1),
                    'time': sig_match.group(2),
                    'entry': int(sig_match.group(3)),  # 1=BUY, -1=SELL
                    'strength': int(sig_match.group(4)),
                    'confluence': float(sig_match.group(5)),
                    'trend_ok': False,
                    'trend_price': 0.0,
                    'rsioma_ok': False,
                    'rsioma_rsi': 0.0,
                    'rsioma_ma': 0.0,
                    'obv_ok': False,
                    'obv_hist': 0.0,
                    'obv_color': -1,
                    'was_executed': False,
                    'was_conflict': False,
                }
                all_signals.append(current_signal)
            
            if current_signal:
                # Passo 1 - Tendência
                trend_match = patterns['trend_ok'].search(line)
                if trend_match:
                    current_signal['trend_ok'] = True
                    current_signal['trend_price'] = float(trend_match.group(1))
                
                # RSIOMA aprovado
                rsioma_app = patterns['rsioma_approved'].search(line)
                if rsioma_app:
                    current_signal['rsioma_ok'] = True
                    current_signal['rsioma_rsi'] = float(rsioma_app.group(1))
                    current_signal['rsioma_ma'] = float(rsioma_app.group(2))
                
                # RSIOMA rejeitado
                if patterns['rsioma_rejected'].search(line):
                    current_signal['rsioma_ok'] = False
                
                # OBV dados
                obv_data = patterns['obv_hist'].search(line)
                if obv_data:
                    current_signal['obv_hist'] = float(obv_data.group(1))
                    current_signal['obv_color'] = int(obv_data.group(2))
                
                # OBV aprovado/rejeitado
                if patterns['obv_approved'].search(line):
                    current_signal['obv_ok'] = True
                if patterns['obv_rejected'].search(line):
                    current_signal['obv_ok'] = False
                
                # Conflito Entry/Strength
                if patterns['conflict'].search(line):
                    current_signal['was_conflict'] = True
            
            # Trade aberto
            trade_match = patterns['trade_open'].search(line)
            if trade_match:
                current_trade = {
                    'open_date': trade_match.group(1),
                    'open_time': trade_match.group(2),
                    'direction': trade_match.group(3),
                    'entry_price': float(trade_match.group(4)),
                    'sl': float(trade_match.group(5)),
                    'tp': float(trade_match.group(6)),
                    'be_activated': False,
                    'trailing_used': False,
                    'close_date': '',
                    'close_time': '',
                    'result': '',
                    'profit': 0.0,
                    'close_reason': '',
                }
                
                # Vincular ao último sinal
                if current_signal:
                    current_signal['was_executed'] = True
                    current_trade['signal_id'] = current_signal['id']
                    current_trade['signal_entry'] = current_signal['entry']
                    current_trade['signal_strength'] = current_signal['strength']
                    current_trade['signal_confluence'] = current_signal['confluence']
                    current_trade['trend_ok'] = current_signal['trend_ok']
                    current_trade['rsioma_ok'] = current_signal['rsioma_ok']
                    current_trade['rsioma_rsi'] = current_signal['rsioma_rsi']
                    current_trade['obv_ok'] = current_signal['obv_ok']
                    current_trade['obv_hist'] = current_signal['obv_hist']
                    current_trade['obv_color'] = current_signal['obv_color']
            
            if current_trade:
                # BE ativado
                if patterns['be_activated'].search(line):
                    current_trade['be_activated'] = True
                
                # Trailing usado
                if patterns['trailing'].search(line):
                    current_trade['trailing_used'] = True
            
            # Trade fechado
            close_match = patterns['trade_close'].search(line)
            if close_match and current_trade:
                current_trade['close_date'] = close_match.group(1)
                current_trade['close_time'] = close_match.group(2)
                current_trade['result'] = close_match.group(3)
                current_trade['profit'] = float(close_match.group(4))
                current_trade['close_reason'] = close_match.group(5).strip()
                all_trades.append(current_trade)
                current_trade = None
    
    return all_signals, all_trades

def analyze_winning_patterns(signals, trades):
    """
    Identifica padrões que diferenciam trades vencedores de perdedores.
    """
    print("=" * 100)
    print("               🔬 ANÁLISE DE PADRÕES VENCEDORES vs PERDEDORES")
    print("=" * 100)
    
    df_trades = pd.DataFrame(trades)
    
    if len(df_trades) == 0:
        print("❌ Nenhum trade encontrado!")
        return None
    
    wins = df_trades[df_trades['result'] == 'WIN']
    losses = df_trades[df_trades['result'] == 'LOSS']
    
    print(f"\n📊 ESTATÍSTICAS GERAIS")
    print(f"   Total de trades: {len(df_trades)}")
    print(f"   Wins: {len(wins)} ({len(wins)/len(df_trades)*100:.1f}%)")
    print(f"   Losses: {len(losses)} ({len(losses)/len(df_trades)*100:.1f}%)")
    print(f"   Lucro Total: ${df_trades['profit'].sum():.2f}")
    print(f"   Lucro Médio por Trade: ${df_trades['profit'].mean():.2f}")
    
    # Separar tipos de WIN
    tp_wins = wins[wins['close_reason'] == 'Take Profit']
    be_wins = wins[wins['close_reason'] == 'Stop Loss']
    
    print(f"\n📈 ANÁLISE DE WINS")
    print(f"   Wins por TP: {len(tp_wins)} (média: ${tp_wins['profit'].mean():.2f})")
    print(f"   Wins por BE/TS: {len(be_wins)} (média: ${be_wins['profit'].mean():.2f})")
    
    print(f"\n📉 ANÁLISE DE LOSSES")
    print(f"   Total de losses: {len(losses)}")
    print(f"   Loss médio: ${losses['profit'].mean():.2f}")
    
    # Análise por força de sinal
    print(f"\n🔍 ANÁLISE POR FORÇA DE SINAL")
    if 'signal_strength' in df_trades.columns:
        for strength in sorted(df_trades['signal_strength'].dropna().unique()):
            str_trades = df_trades[df_trades['signal_strength'] == strength]
            str_wins = str_trades[str_trades['result'] == 'WIN']
            str_profit = str_trades['profit'].sum()
            if len(str_trades) > 0:
                print(f"   F{abs(int(strength)):d}: {len(str_trades)} trades | WR: {len(str_wins)/len(str_trades)*100:.1f}% | Profit: ${str_profit:.2f}")
    
    # Análise por confluência
    print(f"\n🔍 ANÁLISE POR CONFLUÊNCIA")
    if 'signal_confluence' in df_trades.columns:
        df_trades['conf_bucket'] = pd.cut(
            df_trades['signal_confluence'], 
            bins=[0, 60, 80, 100], 
            labels=['<60%', '60-80%', '80-100%']
        )
        for bucket in ['<60%', '60-80%', '80-100%']:
            bucket_trades = df_trades[df_trades['conf_bucket'] == bucket]
            if len(bucket_trades) > 0:
                bucket_wins = bucket_trades[bucket_trades['result'] == 'WIN']
                bucket_profit = bucket_trades['profit'].sum()
                print(f"   {bucket}: {len(bucket_trades)} trades | WR: {len(bucket_wins)/len(bucket_trades)*100:.1f}% | Profit: ${bucket_profit:.2f}")
    
    # Análise OBV
    print(f"\n🔍 ANÁLISE OBV MACD")
    if 'obv_hist' in df_trades.columns:
        print(f"   Trades com OBV Hist > 0: {len(df_trades[df_trades['obv_hist'] > 0])}")
        print(f"   Trades com OBV Hist = 0: {len(df_trades[df_trades['obv_hist'] == 0])}")
        print(f"   Trades com OBV Hist < 0: {len(df_trades[df_trades['obv_hist'] < 0])}")
        
        # Verificar se OBV sempre zero (indicador quebrado)
        if df_trades['obv_hist'].sum() == 0:
            print(f"\n   ⚠️ ALERTA: OBV Histograma está SEMPRE ZERO!")
            print(f"   🔴 PROBLEMA CRÍTICO: Indicador OBV MACD não está gerando dados!")
    
    # Análise RSIOMA
    print(f"\n🔍 ANÁLISE RSIOMA")
    if 'rsioma_rsi' in df_trades.columns:
        for result in ['WIN', 'LOSS']:
            result_trades = df_trades[df_trades['result'] == result]
            if len(result_trades) > 0 and result_trades['rsioma_rsi'].notna().any():
                avg_rsi = result_trades['rsioma_rsi'].mean()
                print(f"   {result}s - RSI médio: {avg_rsi:.1f}")
    
    return df_trades

def analyze_signal_rejection(signals):
    """
    Analisa padrões de sinais rejeitados.
    """
    print("\n" + "=" * 100)
    print("               📊 ANÁLISE DE SINAIS REJEITADOS")
    print("=" * 100)
    
    df = pd.DataFrame(signals)
    
    total = len(df)
    executed = df[df['was_executed'] == True]
    rejected = df[df['was_executed'] == False]
    conflicts = df[df['was_conflict'] == True]
    
    print(f"\n   Total de sinais: {total}")
    print(f"   Executados: {len(executed)} ({len(executed)/total*100:.1f}%)")
    print(f"   Rejeitados: {len(rejected)} ({len(rejected)/total*100:.1f}%)")
    print(f"   Conflitos Entry/Strength: {len(conflicts)} ({len(conflicts)/total*100:.1f}%)")
    
    # Analisar razões de rejeição
    trend_fail = rejected[(rejected['trend_ok'] == False)]
    rsioma_fail = rejected[(rejected['trend_ok'] == True) & (rejected['rsioma_ok'] == False)]
    obv_fail = rejected[(rejected['trend_ok'] == True) & (rejected['rsioma_ok'] == True) & (rejected['obv_ok'] == False)]
    
    print(f"\n   Razões de rejeição (excluindo conflitos):")
    non_conflict_rejected = rejected[rejected['was_conflict'] == False]
    if len(non_conflict_rejected) > 0:
        print(f"      Tendência: {len(trend_fail)} ({len(trend_fail)/len(non_conflict_rejected)*100:.1f}%)")
        print(f"      RSIOMA: {len(rsioma_fail)} ({len(rsioma_fail)/len(non_conflict_rejected)*100:.1f}%)")
        print(f"      OBV: {len(obv_fail)} ({len(obv_fail)/len(non_conflict_rejected)*100:.1f}%)")
    
    return df

def calculate_optimal_parameters(trades):
    """
    Calcula parâmetros ótimos baseados nos dados históricos.
    """
    print("\n" + "=" * 100)
    print("               🎯 PARÂMETROS ÓTIMOS CALCULADOS")
    print("=" * 100)
    
    df = pd.DataFrame(trades)
    
    if len(df) == 0:
        print("❌ Sem trades para análise")
        return
    
    # Calcular SL/TP reais
    if 'entry_price' in df.columns and 'sl' in df.columns:
        df['sl_pips'] = abs(df['entry_price'] - df['sl']) * 1000
        df['tp_pips'] = abs(df['tp'] - df['entry_price']) * 1000
        
        print(f"\n📏 DISTÂNCIAS SL/TP ATUAIS")
        print(f"   SL médio: {df['sl_pips'].mean():.0f} pontos")
        print(f"   TP médio: {df['tp_pips'].mean():.0f} pontos")
        print(f"   R:R configurado: 1:{df['tp_pips'].mean()/df['sl_pips'].mean():.2f}")
    
    # Calcular expectativa matemática
    wins = df[df['result'] == 'WIN']
    losses = df[df['result'] == 'LOSS']
    
    if len(wins) > 0 and len(losses) > 0:
        avg_win = wins['profit'].mean()
        avg_loss = abs(losses['profit'].mean())
        win_rate = len(wins) / len(df)
        
        expected_value = (win_rate * avg_win) - ((1 - win_rate) * avg_loss)
        
        print(f"\n📊 EXPECTATIVA MATEMÁTICA")
        print(f"   Win Rate: {win_rate*100:.1f}%")
        print(f"   Avg Win: ${avg_win:.2f}")
        print(f"   Avg Loss: ${avg_loss:.2f}")
        print(f"   Expected Value: ${expected_value:.2f} por trade")
        
        # Para ser lucrativo com WR atual, qual R:R preciso?
        if win_rate > 0:
            min_rr_for_profit = (1 - win_rate) / win_rate
            print(f"\n   📐 Para WR de {win_rate*100:.1f}%, R:R mínimo necessário: 1:{min_rr_for_profit:.2f}")
            print(f"   📐 R:R atual efetivo: 1:{avg_loss/avg_win:.2f}")
            
            if avg_loss/avg_win > min_rr_for_profit:
                print(f"   ❌ R:R atual é PIOR que o mínimo necessário!")
            else:
                print(f"   ✅ R:R atual é MELHOR que o mínimo necessário!")
        
        # Kelly Criterion
        if avg_loss > 0:
            b = avg_win / avg_loss  # odds
            q = 1 - win_rate  # probability of loss
            kelly = (win_rate * b - q) / b
            print(f"\n   📈 Kelly Criterion: {kelly*100:.1f}%")
            if kelly < 0:
                print(f"   🔴 Kelly NEGATIVO = Sistema NÃO deve ser operado!")
            else:
                print(f"   🟢 Kelly POSITIVO = Sistema pode ser operado")

def generate_new_strategy():
    """
    Gera recomendações para nova estratégia baseada na análise.
    """
    print("\n" + "=" * 100)
    print("               🚀 NOVA ESTRATÉGIA PROPOSTA")
    print("=" * 100)
    
    print("""
╔══════════════════════════════════════════════════════════════════════════════╗
║                     ESTRATÉGIA "TREND CONFIRMATION"                          ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║  OBJETIVO: Operar APENAS a favor da tendência macro com confirmação múltipla║
║                                                                              ║
║  REGRAS DE ENTRADA:                                                          ║
║  ═══════════════════                                                         ║
║                                                                              ║
║  1. TENDÊNCIA (EMA200) - FILTRO PRIMÁRIO                                    ║
║     • BUY: Preço > EMA200 por pelo menos 5 barras                           ║
║     • SELL: Preço < EMA200 por pelo menos 5 barras                          ║
║     • NUNCA entrar contra a EMA200 de longo prazo                           ║
║                                                                              ║
║  2. MOMENTUM (RSI Simples) - FILTRO SECUNDÁRIO                              ║
║     • BUY: RSI(14) > 50 E < 70 (momentum de alta, não sobrecomprado)        ║
║     • SELL: RSI(14) < 50 E > 30 (momentum de baixa, não sobrevendido)       ║
║     • SIMPLIFICAR: Remover RSIOMA complexo, usar RSI básico                 ║
║                                                                              ║
║  3. VOLUME (ATR) - VALIDAÇÃO                                                ║
║     • ATR(14) deve estar acima da média de 50 períodos                      ║
║     • Mercado DEVE ter volatilidade suficiente                               ║
║     • REMOVER OBV MACD (está quebrado, retornando 0)                        ║
║                                                                              ║
║  4. CONFIRMAÇÃO DE PREÇO                                                     ║
║     • Aguardar FECHAMENTO de candle acima/abaixo do nível de entrada        ║
║     • Usar barra 1 (fechada), NUNCA barra 0 (em formação)                   ║
║                                                                              ║
║  REGRAS DE SAÍDA:                                                            ║
║  ════════════════                                                            ║
║                                                                              ║
║  1. STOP LOSS FIXO: 300 pontos (baseado em ATR médio)                       ║
║                                                                              ║
║  2. TAKE PROFIT: 600 pontos (R:R 1:2)                                       ║
║                                                                              ║
║  3. BREAK-EVEN: DESATIVAR (está cortando lucros prematuramente)             ║
║                                                                              ║
║  4. TRAILING STOP: DESATIVAR (mesmo problema)                               ║
║                                                                              ║
║  FILTROS ADICIONAIS:                                                         ║
║  ═══════════════════                                                         ║
║                                                                              ║
║  1. FORÇA DO SINAL: Mínimo F4 (4 EMAs alinhadas)                            ║
║                                                                              ║
║  2. CONFLUÊNCIA: Mínimo 80%                                                 ║
║                                                                              ║
║  3. DIREÇÃO CONSISTENTE: Entry DEVE concordar com Strength                  ║
║     • Entry=1 (BUY) requer Strength > 0                                     ║
║     • Entry=-1 (SELL) requer Strength < 0                                   ║
║                                                                              ║
║  4. REGIME DE MERCADO: Bloquear operações em:                               ║
║     • Mercado lateral (RANGING)                                             ║
║     • Alta volatilidade (VOLATILE)                                          ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝

IMPLEMENTAÇÃO NO CÓDIGO:
═══════════════════════

1. DESATIVAR BE/TS:
   Inp_UseBE = false;
   Inp_UseTrailing = false;

2. AJUSTAR SL/TP para R:R 1:2:
   Inp_SL_Points = 300;
   Inp_TP_RR_Ratio = 2.0; (TP = 600 pontos)

3. AUMENTAR FORÇA MÍNIMA:
   Inp_MinStrength = 4;

4. AUMENTAR CONFLUÊNCIA MÍNIMA:
   Inp_MinConfluence = 80;

5. REMOVER OU DESATIVAR OBV MACD (está quebrado):
   Inp_UseOBVMACD = false;

6. SIMPLIFICAR RSIOMA:
   Usar apenas RSI simples com níveis 30/50/70
   Inp_RSIOMA_CheckMid = true;
   Inp_RSIOMA_CheckCross = false;
   Inp_RSIOMA_Overbought = 70;
   Inp_RSIOMA_Oversold = 30;

7. MANTER FILTRO DE CONFLITO Entry/Strength:
   Já implementado na versão atual.

8. BLOQUEAR REGIMES DESFAVORÁVEIS:
   Inp_BlockRanging = true;
   Inp_BlockVolatile = true;
""")

def main():
    print("🔬 ANÁLISE ESTRATÉGICA DEFINITIVA - EA VERTEX_LOGIC")
    print("=" * 100)
    
    try:
        signals, trades = parse_complete_log(LOG_FILE)
    except Exception as e:
        print(f"❌ Erro ao ler log: {e}")
        return
    
    print(f"\n✅ Dados extraídos:")
    print(f"   Sinais: {len(signals)}")
    print(f"   Trades: {len(trades)}")
    
    # 1. Análise de padrões
    df_trades = analyze_winning_patterns(signals, trades)
    
    # 2. Análise de rejeição
    df_signals = analyze_signal_rejection(signals)
    
    # 3. Parâmetros ótimos
    calculate_optimal_parameters(trades)
    
    # 4. Nova estratégia
    generate_new_strategy()
    
    print("\n" + "=" * 100)
    print("                         FIM DA ANÁLISE")
    print("=" * 100)

if __name__ == "__main__":
    main()
