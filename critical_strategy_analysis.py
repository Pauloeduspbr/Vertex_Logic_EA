#!/usr/bin/env python3
"""
ANÁLISE CRÍTICA DA ESTRATÉGIA - Não apenas parâmetros!

Este script investiga se a estratégia FGM TrendRider é fundamentalmente viável.
"""

import re
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from collections import defaultdict
from statistics import mean, stdev, median
import sys

@dataclass
class TradeRecord:
    time: datetime
    direction: str
    profit: float
    reason: str
    outcome: str
    regime: str = ""
    strength: int = 0
    confluence: float = 0.0
    sl_pts: float = 0.0
    risk_pct: float = 0.0
    spread: float = 0.0
    slope: float = 0.0
    volume: int = 0
    phase: int = 0
    rsi: float = 0.0
    rsi_ma: float = 0.0
    obv: int = 0

def read_log(path: Path) -> str:
    data = path.read_bytes()
    if data.startswith(b'\xff\xfe'):
        return data.decode('utf-16-le')
    try:
        return data.decode('utf-8')
    except:
        return data.decode('latin-1')

def parse_all_trades(content: str) -> list[TradeRecord]:
    """Parse TODOS os trades (WIN e LOSS) com contexto completo"""
    lines = content.splitlines()
    trades = []
    
    # Pattern para BAD ENTRY (losses com contexto completo)
    bad_pattern = re.compile(
        r'(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}).*BAD ENTRY.*Profit=(-?[0-9.]+).*Close=([^|]+)\|.*Dir=(\w+).*Regime=([^|]+)\|.*F=(\d+).*Conf=([0-9.]+)%.*SLpts=([0-9.]+).*Risk=([0-9.]+)%.*Spread=([0-9.]+).*Slope=(-?[0-9.]+).*Vol=(\d+)/.*Phase=(-?\d+).*RSI=([0-9.]+)/MA([0-9.]+).*OBV=(\d+)'
    )
    
    # Pattern para TRADE CLOSED (ambos WIN e LOSS)
    close_pattern = re.compile(
        r'(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}).*TRADE CLOSED:\s+(WIN|LOSS).*Profit:\s+(-?[0-9.]+).*Razão:\s+(.+)'
    )
    
    bad_entries = {}  # Armazenar bad entries por profit para match
    
    for line in lines:
        # Primeiro, armazena BAD ENTRY com contexto
        m = bad_pattern.search(line)
        if m:
            profit = float(m.group(2))
            bad_entries[profit] = {
                'time': datetime.strptime(m.group(1), '%Y.%m.%d %H:%M:%S'),
                'direction': m.group(4),
                'regime': m.group(5).strip(),
                'strength': int(m.group(6)),
                'confluence': float(m.group(7)),
                'sl_pts': float(m.group(8)),
                'risk_pct': float(m.group(9)),
                'spread': float(m.group(10)),
                'slope': float(m.group(11)),
                'volume': int(m.group(12)),
                'phase': int(m.group(13)),
                'rsi': float(m.group(14)),
                'rsi_ma': float(m.group(15)),
                'obv': int(m.group(16))
            }
            continue
        
        # Depois, captura TODOS os fechamentos
        m = close_pattern.search(line)
        if m:
            time = datetime.strptime(m.group(1), '%Y.%m.%d %H:%M:%S')
            outcome = m.group(2)
            profit = float(m.group(3))
            reason = m.group(4).strip()
            
            # Tentar encontrar contexto do BAD ENTRY
            context = bad_entries.get(profit, {})
            
            trades.append(TradeRecord(
                time=time,
                direction=context.get('direction', 'UNKNOWN'),
                profit=profit,
                reason=reason,
                outcome=outcome,
                regime=context.get('regime', ''),
                strength=context.get('strength', 0),
                confluence=context.get('confluence', 0.0),
                sl_pts=context.get('sl_pts', 0.0),
                risk_pct=context.get('risk_pct', 0.0),
                spread=context.get('spread', 0.0),
                slope=context.get('slope', 0.0),
                volume=context.get('volume', 0),
                phase=context.get('phase', 0),
                rsi=context.get('rsi', 0.0),
                rsi_ma=context.get('rsi_ma', 0.0),
                obv=context.get('obv', 0)
            ))
    
    return trades

def analyze_strategy_fundamentals(trades: list[TradeRecord]) -> dict:
    """Análise fundamental da viabilidade da estratégia"""
    
    if not trades:
        return {'error': 'Sem trades'}
    
    wins = [t for t in trades if t.outcome == 'WIN']
    losses = [t for t in trades if t.outcome == 'LOSS']
    
    win_profits = [t.profit for t in wins]
    loss_profits = [abs(t.profit) for t in losses]
    
    # Métricas básicas
    total = len(trades)
    win_count = len(wins)
    loss_count = len(losses)
    win_rate = (win_count / total) * 100 if total > 0 else 0
    
    avg_win = mean(win_profits) if win_profits else 0
    avg_loss = mean(loss_profits) if loss_profits else 0
    
    # Profit Factor
    gross_profit = sum(win_profits)
    gross_loss = sum(loss_profits)
    pf = gross_profit / gross_loss if gross_loss > 0 else 0
    
    # Expectancy
    ev = (win_rate/100 * avg_win) - ((100-win_rate)/100 * avg_loss)
    
    # R:R ratio
    rr = avg_win / avg_loss if avg_loss > 0 else 0
    
    # Análise de risco
    risks = [t.risk_pct for t in trades if t.risk_pct > 0]
    avg_risk = mean(risks) if risks else 0
    max_risk = max(risks) if risks else 0
    
    # Análise por regime
    by_regime = defaultdict(lambda: {'wins': 0, 'losses': 0, 'profit': 0})
    for t in trades:
        regime = t.regime or 'UNKNOWN'
        if t.outcome == 'WIN':
            by_regime[regime]['wins'] += 1
        else:
            by_regime[regime]['losses'] += 1
        by_regime[regime]['profit'] += t.profit
    
    # Análise por direção
    by_direction = defaultdict(lambda: {'wins': 0, 'losses': 0, 'profit': 0})
    for t in trades:
        direction = t.direction or 'UNKNOWN'
        if t.outcome == 'WIN':
            by_direction[direction]['wins'] += 1
        else:
            by_direction[direction]['losses'] += 1
        by_direction[direction]['profit'] += t.profit
    
    # Análise por razão de fechamento
    by_reason = defaultdict(lambda: {'wins': 0, 'losses': 0, 'profit': 0})
    for t in trades:
        if t.outcome == 'WIN':
            by_reason[t.reason]['wins'] += 1
        else:
            by_reason[t.reason]['losses'] += 1
        by_reason[t.reason]['profit'] += t.profit
    
    # OBV sempre zero?
    obv_zero = sum(1 for t in trades if t.obv == 0)
    obv_zero_pct = (obv_zero / total) * 100 if total > 0 else 0
    
    return {
        'total': total,
        'wins': win_count,
        'losses': loss_count,
        'win_rate': win_rate,
        'avg_win': avg_win,
        'avg_loss': avg_loss,
        'gross_profit': gross_profit,
        'gross_loss': gross_loss,
        'net_profit': gross_profit - gross_loss,
        'profit_factor': pf,
        'expectancy': ev,
        'rr_ratio': rr,
        'avg_risk_pct': avg_risk,
        'max_risk_pct': max_risk,
        'by_regime': dict(by_regime),
        'by_direction': dict(by_direction),
        'by_reason': dict(by_reason),
        'obv_zero_pct': obv_zero_pct,
        'win_profits': win_profits,
        'loss_profits': loss_profits,
    }

def diagnose_fundamental_issues(stats: dict) -> list[dict]:
    """Diagnostica problemas FUNDAMENTAIS da estratégia"""
    issues = []
    
    # 1. Risco por trade absurdo
    if stats['avg_risk_pct'] > 10:
        issues.append({
            'severity': 'FATAL',
            'category': 'GESTÃO DE RISCO',
            'issue': f'Risco médio por trade: {stats["avg_risk_pct"]:.0f}% (máx: {stats["max_risk_pct"]:.0f}%)',
            'expected': 'Risco por trade deveria ser 1-2% máximo',
            'root_cause': 'CRiskManager não está limitando o tamanho da posição corretamente',
            'fix': 'Verificar cálculo de lote em CRiskManager.CalcPositionSize()'
        })
    
    # 2. R:R invertido (wins menores que losses)
    if stats['rr_ratio'] < 1.0:
        issues.append({
            'severity': 'CRÍTICO',
            'category': 'SAÍDAS',
            'issue': f'R:R = 1:{1/stats["rr_ratio"]:.2f} - Wins (${stats["avg_win"]:.2f}) menores que Losses (${stats["avg_loss"]:.2f})',
            'expected': 'R:R deveria ser pelo menos 1:1, idealmente 1.5:1 ou maior',
            'root_cause': 'Trailing Stop fecha trades WIN muito cedo, mas deixa LOSS correrem até SL',
            'fix': 'Aumentar distância do trailing OU usar TP fixo sem trailing'
        })
    
    # 3. Profit Factor < 1
    if stats['profit_factor'] < 1.0:
        issues.append({
            'severity': 'CRÍTICO',
            'category': 'ESTRATÉGIA',
            'issue': f'Profit Factor = {stats["profit_factor"]:.2f} - Sistema perde dinheiro sistemicamente',
            'expected': 'PF >= 1.5 para sistema viável',
            'root_cause': 'Combinação de WinRate insuficiente + R:R ruim',
            'fix': 'Melhorar seleção de trades E/OU melhorar gestão de saídas'
        })
    
    # 4. OBV sempre zero
    if stats['obv_zero_pct'] > 90:
        issues.append({
            'severity': 'ALTO',
            'category': 'INDICADORES',
            'issue': f'OBV = 0 em {stats["obv_zero_pct"]:.0f}% dos trades',
            'expected': 'OBV deveria variar com volume do mercado',
            'root_cause': 'Indicador OBV MACD não está calculando ou não tem dados',
            'fix': 'Verificar se indicador OBV_MACD_v3.ex5 está compilado e funcionando'
        })
    
    # 5. Mais losses que wins em direção específica
    for direction, data in stats.get('by_direction', {}).items():
        total = data['wins'] + data['losses']
        if total >= 5:
            wr = (data['wins'] / total) * 100
            if wr < 40:
                issues.append({
                    'severity': 'ALTO',
                    'category': 'DIREÇÃO',
                    'issue': f'{direction} tem WinRate de {wr:.0f}% ({data["wins"]}W/{data["losses"]}L)',
                    'expected': 'WinRate >= 50% por direção',
                    'root_cause': f'Sinais {direction} não são confiáveis neste mercado/timeframe',
                    'fix': f'Desativar {direction} ou adicionar filtros direcionais mais rigorosos'
                })
    
    # 6. Regime específico muito ruim
    for regime, data in stats.get('by_regime', {}).items():
        if regime and data['profit'] < -10:
            total = data['wins'] + data['losses']
            if total >= 3:
                issues.append({
                    'severity': 'ALTO',
                    'category': 'REGIME',
                    'issue': f'Regime {regime}: perda de ${abs(data["profit"]):.2f} ({data["wins"]}W/{data["losses"]}L)',
                    'expected': 'Cada regime deveria ser lucrativo ou evitado',
                    'root_cause': f'EA opera em mercado {regime} mas estratégia não funciona nele',
                    'fix': f'Evitar trades em regime {regime} ou ajustar parâmetros específicos'
                })
    
    # 7. Take Profit nunca atingido
    tp_hits = stats.get('by_reason', {}).get('Take Profit', {'wins': 0, 'losses': 0})
    sl_hits = stats.get('by_reason', {}).get('Stop Loss', {'wins': 0, 'losses': 0})
    
    if tp_hits['wins'] == 0 and sl_hits['wins'] + sl_hits['losses'] > 10:
        issues.append({
            'severity': 'CRÍTICO',
            'category': 'SAÍDAS',
            'issue': 'Take Profit NUNCA atingido - todas saídas via Stop Loss',
            'expected': 'Mix saudável de TP e SL (trailing)',
            'root_cause': 'TP muito longe OU Trailing Stop muito agressivo move SL para lucro',
            'fix': 'Reduzir distância do TP OU aumentar trigger do Trailing Stop'
        })
    
    return issues

def calculate_required_changes(stats: dict) -> dict:
    """Calcula o que PRECISA mudar para ser lucrativo"""
    
    win_rate = stats['win_rate'] / 100
    loss_rate = 1 - win_rate
    avg_loss = stats['avg_loss']
    
    # Para breakeven: WinRate * AvgWin = LossRate * AvgLoss
    min_win_breakeven = (loss_rate / win_rate) * avg_loss if win_rate > 0 else float('inf')
    
    # Para PF = 1.5
    min_win_profitable = 1.5 * avg_loss * loss_rate / win_rate if win_rate > 0 else float('inf')
    
    # Alternativa: que WinRate precisamos com R:R atual?
    rr = stats['rr_ratio']
    if rr > 0:
        min_winrate_breakeven = 1 / (1 + rr)
        min_winrate_profitable = 1 / (1 + rr * 0.67)  # Para PF = 1.5
    else:
        min_winrate_breakeven = 1.0
        min_winrate_profitable = 1.0
    
    return {
        'current_win_rate': stats['win_rate'],
        'current_avg_win': stats['avg_win'],
        'current_avg_loss': avg_loss,
        'current_rr': rr,
        'min_win_for_breakeven': min_win_breakeven,
        'min_win_for_profit': min_win_profitable,
        'min_winrate_for_breakeven': min_winrate_breakeven * 100,
        'min_winrate_for_profit': min_winrate_profitable * 100,
    }

def generate_critical_report(stats: dict, issues: list, required: dict, trades: list) -> str:
    """Gera relatório crítico da estratégia"""
    
    lines = []
    lines.append("# 🚨 ANÁLISE CRÍTICA DA ESTRATÉGIA FGM TrendRider\n")
    lines.append("---\n")
    
    # VEREDICTO
    if stats['profit_factor'] < 0.8:
        verdict = "❌ ESTRATÉGIA FUNDAMENTALMENTE FALHA"
        verdict_detail = "A estratégia perde dinheiro de forma sistemática. MUDANÇAS DE PARÂMETROS NÃO RESOLVERÃO."
    elif stats['profit_factor'] < 1.0:
        verdict = "⚠️ ESTRATÉGIA MARGINALMENTE VIÁVEL"
        verdict_detail = "Próximo do breakeven mas ainda perde. Precisa ajustes significativos."
    else:
        verdict = "✅ ESTRATÉGIA VIÁVEL"
        verdict_detail = "Profit Factor positivo. Parâmetros podem ser otimizados."
    
    lines.append(f"## {verdict}\n")
    lines.append(f"**{verdict_detail}**\n")
    
    # Estatísticas Chave
    lines.append("## 📊 Estatísticas Chave\n")
    lines.append(f"| Métrica | Valor | Avaliação |")
    lines.append(f"|---------|-------|-----------|")
    lines.append(f"| Total Trades | {stats['total']} | |")
    lines.append(f"| Win Rate | {stats['win_rate']:.1f}% | {'✅' if stats['win_rate'] >= 55 else '⚠️'} |")
    lines.append(f"| Avg Win | ${stats['avg_win']:.2f} | {'✅' if stats['avg_win'] >= stats['avg_loss'] else '❌'} |")
    lines.append(f"| Avg Loss | ${stats['avg_loss']:.2f} | |")
    lines.append(f"| R:R Ratio | 1:{1/stats['rr_ratio']:.2f} | {'✅' if stats['rr_ratio'] >= 1 else '❌ INVERTIDO'} |")
    lines.append(f"| Profit Factor | {stats['profit_factor']:.2f} | {'✅' if stats['profit_factor'] >= 1.0 else '❌'} |")
    lines.append(f"| Expectancy | ${stats['expectancy']:.2f}/trade | {'✅' if stats['expectancy'] > 0 else '❌'} |")
    lines.append(f"| Net P&L | ${stats['net_profit']:.2f} | {'✅' if stats['net_profit'] > 0 else '❌'} |")
    lines.append(f"| Avg Risk/Trade | {stats['avg_risk_pct']:.0f}% | {'✅' if stats['avg_risk_pct'] <= 5 else '❌ MUITO ALTO'} |")
    
    # Problemas Fundamentais
    lines.append("\n## 🔴 PROBLEMAS FUNDAMENTAIS\n")
    
    for i, issue in enumerate(issues, 1):
        lines.append(f"### {i}. [{issue['severity']}] {issue['category']}")
        lines.append(f"**Problema:** {issue['issue']}")
        lines.append(f"**Esperado:** {issue['expected']}")
        lines.append(f"**Causa Raiz:** {issue['root_cause']}")
        lines.append(f"**Correção:** {issue['fix']}\n")
    
    # Matemática do Que Precisa Mudar
    lines.append("## 🧮 MATEMÁTICA DA LUCRATIVIDADE\n")
    lines.append(f"### Com WinRate atual de {required['current_win_rate']:.1f}%:")
    lines.append(f"- Avg Win mínimo para **breakeven**: ${required['min_win_for_breakeven']:.2f}")
    lines.append(f"- Avg Win mínimo para **PF=1.5**: ${required['min_win_for_profit']:.2f}")
    lines.append(f"- **Sua média atual**: ${required['current_avg_win']:.2f} ❌\n")
    
    lines.append(f"### Com R:R atual de 1:{1/required['current_rr']:.2f}:")
    lines.append(f"- WinRate mínimo para **breakeven**: {required['min_winrate_for_breakeven']:.1f}%")
    lines.append(f"- WinRate mínimo para **PF=1.5**: {required['min_winrate_for_profit']:.1f}%")
    lines.append(f"- **Seu WinRate atual**: {required['current_win_rate']:.1f}%\n")
    
    # Por Rasão de Fechamento  
    lines.append("## 📈 Por Razão de Fechamento\n")
    lines.append("| Razão | Wins | Losses | P&L |")
    lines.append("|-------|------|--------|-----|")
    for reason, data in stats.get('by_reason', {}).items():
        pnl = data['profit']
        lines.append(f"| {reason} | {data['wins']} | {data['losses']} | ${pnl:.2f} |")
    
    # Por Regime
    lines.append("\n## 📉 Por Regime de Mercado\n")
    lines.append("| Regime | Wins | Losses | P&L | WinRate |")
    lines.append("|--------|------|--------|-----|---------|")
    for regime, data in sorted(stats.get('by_regime', {}).items(), key=lambda x: x[1]['profit']):
        total = data['wins'] + data['losses']
        wr = (data['wins'] / total * 100) if total > 0 else 0
        lines.append(f"| {regime} | {data['wins']} | {data['losses']} | ${data['profit']:.2f} | {wr:.0f}% |")
    
    # Por Direção
    lines.append("\n## ↕️ Por Direção\n")
    lines.append("| Direção | Wins | Losses | P&L | WinRate |")
    lines.append("|---------|------|--------|-----|---------|")
    for direction, data in stats.get('by_direction', {}).items():
        total = data['wins'] + data['losses']
        wr = (data['wins'] / total * 100) if total > 0 else 0
        lines.append(f"| {direction} | {data['wins']} | {data['losses']} | ${data['profit']:.2f} | {wr:.0f}% |")
    
    # Recomendações Finais
    lines.append("\n## ✅ RECOMENDAÇÕES CRÍTICAS\n")
    
    # Baseado nos problemas, dar recomendações prioritárias
    fatal_issues = [i for i in issues if i['severity'] == 'FATAL']
    critical_issues = [i for i in issues if i['severity'] == 'CRÍTICO']
    
    if fatal_issues:
        lines.append("### 🔴 PRIORIDADE MÁXIMA (FATAL)")
        for issue in fatal_issues:
            lines.append(f"- **{issue['category']}**: {issue['fix']}")
    
    if critical_issues:
        lines.append("\n### 🟠 ALTA PRIORIDADE (CRÍTICO)")
        for issue in critical_issues:
            lines.append(f"- **{issue['category']}**: {issue['fix']}")
    
    lines.append("\n### 💡 ALTERNATIVAS ESTRUTURAIS")
    lines.append("1. **Desativar Trailing Stop completamente** - Usar apenas TP fixo")
    lines.append("2. **Reduzir SL drasticamente** - SL=100pts com TP=150pts (R:R 1.5:1)")
    lines.append("3. **Inverter a estratégia** - Se sempre perde, fazer o oposto?")
    lines.append("4. **Filtrar por horário** - Evitar horários de baixa liquidez (00:00-08:00)")
    lines.append("5. **Operar apenas BUY ou apenas SELL** - Uma direção pode ser mais confiável")
    
    return "\n".join(lines)

def main():
    log_path = Path(__file__).parent / "20251216.log"
    
    if not log_path.exists():
        print(f"❌ Log não encontrado: {log_path}")
        return 1
    
    print("=" * 70)
    print("ANÁLISE CRÍTICA DA ESTRATÉGIA")
    print("=" * 70)
    
    print(f"\n📂 Lendo: {log_path.name}")
    content = read_log(log_path)
    
    print("\n🔍 Analisando trades...")
    trades = parse_all_trades(content)
    print(f"   {len(trades)} trades encontrados")
    
    if not trades:
        print("❌ Nenhum trade encontrado!")
        return 1
    
    print("\n📊 Calculando estatísticas...")
    stats = analyze_strategy_fundamentals(trades)
    
    print("\n🔴 Diagnosticando problemas...")
    issues = diagnose_fundamental_issues(stats)
    print(f"   {len(issues)} problemas encontrados")
    
    print("\n🧮 Calculando requisitos...")
    required = calculate_required_changes(stats)
    
    print("\n📝 Gerando relatório...")
    report = generate_critical_report(stats, issues, required, trades)
    
    report_path = log_path.parent / "analise_critica_estrategia.md"
    report_path.write_text(report, encoding='utf-8')
    print(f"   Salvo em: {report_path.name}")
    
    # Resumo no console
    print("\n" + "=" * 70)
    print("VEREDICTO")
    print("=" * 70)
    
    if stats['profit_factor'] < 0.8:
        print("\n❌ ESTRATÉGIA FUNDAMENTALMENTE FALHA")
        print("   Mudanças de parâmetros NÃO VÃO RESOLVER!")
    elif stats['profit_factor'] < 1.0:
        print("\n⚠️ ESTRATÉGIA MARGINALMENTE VIÁVEL")
        print("   Precisa mudanças ESTRUTURAIS, não apenas parâmetros")
    else:
        print("\n✅ ESTRATÉGIA VIÁVEL")
        print("   Otimização de parâmetros pode ajudar")
    
    print(f"\nProfit Factor: {stats['profit_factor']:.2f}")
    print(f"Win Rate: {stats['win_rate']:.1f}%")
    print(f"Avg Win: ${stats['avg_win']:.2f}")
    print(f"Avg Loss: ${stats['avg_loss']:.2f}")
    print(f"R:R: 1:{1/stats['rr_ratio']:.2f}")
    print(f"Net P&L: ${stats['net_profit']:.2f}")
    print(f"Risco médio/trade: {stats['avg_risk_pct']:.0f}%")
    
    print("\n" + "=" * 70)
    print("PROBLEMAS FATAIS/CRÍTICOS")
    print("=" * 70)
    
    for issue in issues:
        if issue['severity'] in ['FATAL', 'CRÍTICO']:
            print(f"\n❌ [{issue['severity']}] {issue['category']}")
            print(f"   {issue['issue']}")
            print(f"   → FIX: {issue['fix']}")
    
    return 0

if __name__ == "__main__":
    exit(main())
