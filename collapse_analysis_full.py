#!/usr/bin/env python3
"""
Análise Completa do Colapso do EA FGM_TrendRider
Identifica problemas de estratégia e filtros fracos a partir do dia 26
"""

import re
from datetime import datetime, timedelta
from collections import defaultdict

def analyze_collapse(log_path, collapse_date="2023.01.26"):
    """Analisa o log para identificar o problema do colapso"""
    
    # Ler o log (tentar UTF-8 primeiro, já convertido)
    try:
        with open(log_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except:
        with open(log_path, 'r', encoding='utf-16') as f:
            lines = f.readlines()
    
    collapse_dt = datetime.strptime(collapse_date, "%Y.%m.%d")
    
    # Dados coletados
    trades_before = []
    trades_after = []
    signals_before = []
    signals_after = []
    filters_blocked_before = defaultdict(int)
    filters_blocked_after = defaultdict(int)
    entries_by_direction = {'before': {'BUY': 0, 'SELL': 0}, 'after': {'BUY': 0, 'SELL': 0}}
    
    # Regex patterns
    trade_regex = r"(\d{4}\.\d{2}\.\d{2})\s+\d{2}:\d{2}:\d{2}.*Posição fechada - Lucro:\s*([-\d.]+)\s*\|\s*Razão:\s*(.+)"
    signal_regex = r"(\d{4}\.\d{2}\.\d{2})\s+\d{2}:\d{2}:\d{2}.*Sinal detectado.*Entry=([-\d]+).*Strength=([-\d]+).*Confluence=([\d.]+)%"
    filter_regex = r"(\d{4}\.\d{2}\.\d{2})\s+\d{2}:\d{2}:\d{2}.*FILTRO BLOQUEOU:\s*(.+)"
    rsioma_debug = r"(\d{4}\.\d{2}\.\d{2})\s+\d{2}:\d{2}:\d{2}.*RSIOMA FILTRO:\s*(BUY|SELL)\s*(APROVADO|BLOQUEADO)"
    obvmacd_debug = r"(\d{4}\.\d{2}\.\d{2})\s+\d{2}:\d{2}:\d{2}.*OBV MACD:.*\((Verde|Vermelho|Neutro).*\).*-\s*(APROVADO|BLOQUEADO)"
    
    for line in lines:
        # Parse timestamp
        ts_match = re.search(r"(\d{4}\.\d{2}\.\d{2})", line)
        if not ts_match:
            continue
        
        try:
            current_dt = datetime.strptime(ts_match.group(1), "%Y.%m.%d")
        except:
            continue
        
        is_after = current_dt >= collapse_dt
        period = 'after' if is_after else 'before'
        
        # Parse trades
        trade_match = re.search(trade_regex, line)
        if trade_match:
            profit = float(trade_match.group(2))
            reason = trade_match.group(3).strip()
            trade = {
                'date': ts_match.group(1),
                'profit': profit,
                'reason': reason,
                'is_win': profit > 0
            }
            if is_after:
                trades_after.append(trade)
            else:
                trades_before.append(trade)
        
        # Parse signals
        sig_match = re.search(signal_regex, line)
        if sig_match:
            entry = int(sig_match.group(2))
            strength = int(sig_match.group(3))
            confluence = float(sig_match.group(4))
            direction = 'BUY' if entry == 1 else 'SELL' if entry == -1 else 'NONE'
            signal = {
                'date': ts_match.group(1),
                'direction': direction,
                'strength': strength,
                'confluence': confluence
            }
            if is_after:
                signals_after.append(signal)
                entries_by_direction['after'][direction] = entries_by_direction['after'].get(direction, 0) + 1
            else:
                signals_before.append(signal)
                entries_by_direction['before'][direction] = entries_by_direction['before'].get(direction, 0) + 1
        
        # Parse filter blocks
        filter_match = re.search(filter_regex, line)
        if filter_match:
            reason = filter_match.group(2).strip()
            # Simplificar razão para categorização
            if 'Spread' in reason:
                reason_key = 'Spread alto'
            elif 'OBV MACD' in reason:
                reason_key = 'OBV MACD bloqueou'
            elif 'RSIOMA' in reason:
                reason_key = 'RSIOMA bloqueou'
            elif 'Fase' in reason:
                reason_key = 'Fase inadequada'
            elif 'Cooldown' in reason:
                reason_key = 'Cooldown'
            elif 'ATR' in reason:
                reason_key = 'ATR filtro'
            else:
                reason_key = reason[:30]
            
            if is_after:
                filters_blocked_after[reason_key] += 1
            else:
                filters_blocked_before[reason_key] += 1
    
    # Calcular estatísticas
    print("=" * 80)
    print("ANÁLISE DO COLAPSO DO EA FGM_TrendRider")
    print(f"Data do Colapso: {collapse_date}")
    print("=" * 80)
    
    # Estatísticas de Trades
    print("\n" + "=" * 40)
    print("📊 ESTATÍSTICAS DE TRADES")
    print("=" * 40)
    
    def calc_stats(trades, label):
        if not trades:
            print(f"\n{label}: Sem trades")
            return
        
        wins = [t for t in trades if t['is_win']]
        losses = [t for t in trades if not t['is_win']]
        total_profit = sum(t['profit'] for t in trades)
        avg_profit = total_profit / len(trades)
        win_rate = len(wins) / len(trades) * 100
        
        avg_win = sum(t['profit'] for t in wins) / len(wins) if wins else 0
        avg_loss = sum(t['profit'] for t in losses) / len(losses) if losses else 0
        
        # Contar SL cheios (perda de ~-18)
        full_sl_losses = [t for t in losses if t['profit'] < -15]
        
        print(f"\n{label}:")
        print(f"  Total de trades: {len(trades)}")
        print(f"  Wins: {len(wins)} | Losses: {len(losses)}")
        print(f"  Win Rate: {win_rate:.1f}%")
        print(f"  Lucro Total: ${total_profit:.2f}")
        print(f"  Média por trade: ${avg_profit:.2f}")
        print(f"  Média WIN: ${avg_win:.2f} | Média LOSS: ${avg_loss:.2f}")
        print(f"  ⚠️  Stop Loss CHEIO (-18): {len(full_sl_losses)} trades ({len(full_sl_losses)/len(trades)*100:.1f}%)")
        
        # Listar trades
        print(f"\n  Trades detalhados:")
        for t in trades:
            status = "✅" if t['is_win'] else "❌"
            print(f"    {status} {t['date']}: ${t['profit']:>7.2f} | {t['reason']}")
    
    calc_stats(trades_before, "ANTES do Colapso")
    calc_stats(trades_after, "DEPOIS do Colapso")
    
    # Comparação de Sinais
    print("\n" + "=" * 40)
    print("📊 ANÁLISE DE SINAIS")
    print("=" * 40)
    
    print(f"\nSinais ANTES do colapso: {len(signals_before)}")
    print(f"  BUY: {entries_by_direction['before'].get('BUY', 0)} | SELL: {entries_by_direction['before'].get('SELL', 0)}")
    if signals_before:
        avg_str_before = sum(abs(s['strength']) for s in signals_before) / len(signals_before)
        avg_conf_before = sum(s['confluence'] for s in signals_before) / len(signals_before)
        print(f"  Média Strength: {avg_str_before:.1f} | Média Confluence: {avg_conf_before:.1f}%")
    
    print(f"\nSinais DEPOIS do colapso: {len(signals_after)}")
    print(f"  BUY: {entries_by_direction['after'].get('BUY', 0)} | SELL: {entries_by_direction['after'].get('SELL', 0)}")
    if signals_after:
        avg_str_after = sum(abs(s['strength']) for s in signals_after) / len(signals_after)
        avg_conf_after = sum(s['confluence'] for s in signals_after) / len(signals_after)
        print(f"  Média Strength: {avg_str_after:.1f} | Média Confluence: {avg_conf_after:.1f}%")
    
    # Análise de Filtros
    print("\n" + "=" * 40)
    print("🚫 ANÁLISE DE FILTROS (BLOQUEIOS)")
    print("=" * 40)
    
    print(f"\nBloqueios ANTES do colapso:")
    for reason, count in sorted(filters_blocked_before.items(), key=lambda x: -x[1]):
        print(f"  {reason}: {count}")
    
    print(f"\nBloqueios DEPOIS do colapso:")
    for reason, count in sorted(filters_blocked_after.items(), key=lambda x: -x[1]):
        print(f"  {reason}: {count}")
    
    # DIAGNÓSTICO
    print("\n" + "=" * 80)
    print("🔍 DIAGNÓSTICO DO PROBLEMA")
    print("=" * 80)
    
    problems_found = []
    
    # 1. Verificar se os trades após o colapso são todos SL cheios
    if trades_after:
        full_sl = [t for t in trades_after if t['profit'] < -15]
        if len(full_sl) / len(trades_after) > 0.5:
            problems_found.append(
                f"❌ PROBLEMA CRÍTICO: {len(full_sl)/len(trades_after)*100:.0f}% dos trades após {collapse_date} "
                f"são Stop Loss CHEIO (-18), indicando que:\n"
                f"   → Trailing Stop NÃO está movendo o SL para proteger lucro\n"
                f"   → Break Even NÃO está sendo ativado\n"
                f"   → O preço se move contra a entrada imediatamente"
            )
    
    # 2. Verificar se win rate caiu
    if trades_before and trades_after:
        wr_before = len([t for t in trades_before if t['is_win']]) / len(trades_before) * 100
        wr_after = len([t for t in trades_after if t['is_win']]) / len(trades_after) * 100
        if wr_after < wr_before - 20:
            problems_found.append(
                f"❌ QUEDA DE WIN RATE: {wr_before:.0f}% → {wr_after:.0f}%\n"
                f"   → Filtros estão deixando passar sinais fracos\n"
                f"   → Confluência mínima pode estar muito baixa"
            )
    
    # 3. Verificar direção dominante
    if signals_after:
        buy_after = entries_by_direction['after'].get('BUY', 0)
        sell_after = entries_by_direction['after'].get('SELL', 0)
        if buy_after > sell_after * 2 or sell_after > buy_after * 2:
            dominant = 'BUY' if buy_after > sell_after else 'SELL'
            problems_found.append(
                f"⚠️  VIÉS DIRECIONAL: O EA está entrando majoritariamente em {dominant}\n"
                f"   → Se mercado está contra essa direção, todos os trades perdem"
            )
    
    # 4. Verificar confluência baixa
    if signals_after:
        low_conf = [s for s in signals_after if s['confluence'] < 50]
        if len(low_conf) / len(signals_after) > 0.5:
            problems_found.append(
                f"⚠️  CONFLUÊNCIA FRACA: {len(low_conf)/len(signals_after)*100:.0f}% dos sinais têm confluência < 50%\n"
                f"   → Aumentar Min_Confluence para pelo menos 50%"
            )
    
    # 5. Verificar se filtros estão bloqueando muito pouco
    total_blocks_after = sum(filters_blocked_after.values())
    if signals_after and total_blocks_after < len(signals_after) * 0.3:
        problems_found.append(
            f"⚠️  FILTROS FRACOS: Apenas {total_blocks_after} bloqueios para {len(signals_after)} sinais\n"
            f"   → Os filtros não estão rejeitando sinais ruins suficientemente"
        )
    
    for i, problem in enumerate(problems_found, 1):
        print(f"\n{i}. {problem}")
    
    if not problems_found:
        print("\n✅ Nenhum problema óbvio detectado nos dados disponíveis.")
    
    # RECOMENDAÇÕES
    print("\n" + "=" * 80)
    print("💡 RECOMENDAÇÕES PARA CORREÇÃO")
    print("=" * 80)
    
    recommendations = [
        "1. VERIFICAR TRAILING STOP E BREAK EVEN:",
        "   - Os valores de SL cheio indicam que o trailing nunca move o stop",
        "   - Reduzir Trailing_Trigger de 350 para 150-200 pips",
        "   - Reduzir BE_Trigger de 200 para 100-150 pips",
        "",
        "2. AUMENTAR CONFLUÊNCIA MÍNIMA:",
        "   - Muitos sinais com confluência de 10% estão passando",
        "   - Definir Min_Confluence para 50% ou mais",
        "",
        "3. FORTALECER FILTRO DE FORÇA:",
        "   - Strength de ±3 ou ±4 é fraco",
        "   - Exigir Strength mínimo de ±5 para entradas",
        "",
        "4. VERIFICAR REGIME DE MERCADO:",
        "   - Se mercado mudou de TREND para RANGE após dia 26",
        "   - O EA pode estar entrando em tendência quando não há",
        "",
        "5. REVISAR LÓGICA DE ENTRADA:",
        "   - Verificar se o sinal está alinhado com a tendência maior",
        "   - Adicionar filtro de tendência em timeframe superior"
    ]
    
    for rec in recommendations:
        print(rec)
    
    return {
        'trades_before': trades_before,
        'trades_after': trades_after,
        'problems': problems_found
    }

if __name__ == "__main__":
    import sys
    log_file = sys.argv[1] if len(sys.argv) > 1 else "20251215_utf8.log"
    analyze_collapse(log_file)
