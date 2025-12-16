#!/usr/bin/env python3
"""
Análise Completa do EA FGM TrendRider - Identificação de Problemas de Lucratividade

Este script realiza análise matemática e financeira detalhada do log do EA
para identificar por que ele não é lucrativo e quebra a conta.
"""

import re
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from statistics import mean, stdev
from collections import defaultdict

# Configuração
LOG_PATH = Path(__file__).parent / "20251215.log"

@dataclass
class Trade:
    """Representa um trade executado"""
    open_time: datetime
    close_time: datetime
    direction: str  # BUY/SELL
    entry_price: float
    sl: float
    tp: float
    volume: float
    profit: float
    close_reason: str
    strength: int = 0
    confluence: float = 0.0
    sl_distance_pips: float = 0.0
    tp_distance_pips: float = 0.0

def read_log(path: Path) -> str:
    """Lê o log em UTF-16LE ou UTF-8"""
    data = path.read_bytes()
    if data.startswith(b'\xff\xfe'):
        return data.decode('utf-16-le')
    try:
        return data.decode('utf-8')
    except:
        return data.decode('latin-1')

def parse_trades(lines: list[str]) -> list[Trade]:
    """Extrai trades do log"""
    trades = []
    
    # Padrões de regex
    open_pattern = re.compile(
        r'(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}).*\[INFO\]\s+TRADE:\s+(BUY|SELL)\s+@\s+([0-9.]+)\s+\|\s+Vol:\s+([0-9.]+)\s+\|\s+SL:\s+([0-9.]+)\s+\|\s+TP:\s+([0-9.]+)'
    )
    
    close_pattern = re.compile(
        r'(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}).*\[INFO\]\s+TRADE CLOSED:\s+(WIN|LOSS)\s+\|\s+Profit:\s+(-?[0-9.]+)\s+\|\s+Raz[aã]o:\s+(.+)'
    )
    
    signal_pattern = re.compile(
        r'(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}).*\[INFO\]\s+Sinal detectado!.*Strength=(-?\d+),\s+Confluence=([0-9.]+)%'
    )
    
    opens = []
    closes = []
    signals = []
    
    for line in lines:
        # Parse opens
        m = open_pattern.search(line)
        if m:
            opens.append({
                'time': datetime.strptime(m.group(1), '%Y.%m.%d %H:%M:%S'),
                'direction': m.group(2),
                'price': float(m.group(3)),
                'volume': float(m.group(4)),
                'sl': float(m.group(5)),
                'tp': float(m.group(6)),
            })
            continue
        
        # Parse closes
        m = close_pattern.search(line)
        if m:
            closes.append({
                'time': datetime.strptime(m.group(1), '%Y.%m.%d %H:%M:%S'),
                'outcome': m.group(2),
                'profit': float(m.group(3)),
                'reason': m.group(4).strip(),
            })
            continue
        
        # Parse signals
        m = signal_pattern.search(line)
        if m:
            signals.append({
                'time': datetime.strptime(m.group(1), '%Y.%m.%d %H:%M:%S'),
                'strength': int(m.group(2)),
                'confluence': float(m.group(3)),
            })
    
    # Pair opens with closes
    for i, (o, c) in enumerate(zip(opens, closes)):
        # Find nearest signal before open
        signal = None
        for s in reversed(signals):
            if s['time'] <= o['time']:
                signal = s
                break
        
        # Calculate SL/TP distances in pips (for USDJPY, 1 pip = 0.01)
        point = 0.001  # USDJPY point
        sl_dist = abs(o['price'] - o['sl']) / point
        tp_dist = abs(o['tp'] - o['price']) / point
        
        trades.append(Trade(
            open_time=o['time'],
            close_time=c['time'],
            direction=o['direction'],
            entry_price=o['price'],
            sl=o['sl'],
            tp=o['tp'],
            volume=o['volume'],
            profit=c['profit'],
            close_reason=c['reason'],
            strength=abs(signal['strength']) if signal else 0,
            confluence=signal['confluence'] if signal else 0.0,
            sl_distance_pips=sl_dist,
            tp_distance_pips=tp_dist,
        ))
    
    return trades

def analyze_trades(trades: list[Trade], initial_deposit: float = 100.0) -> dict:
    """Análise estatística completa dos trades"""
    if not trades:
        return {}
    
    profits = [t.profit for t in trades]
    wins = [p for p in profits if p > 0]
    losses = [p for p in profits if p < 0]
    
    # Métricas básicas
    total_trades = len(trades)
    win_count = len(wins)
    loss_count = len(losses)
    win_rate = (win_count / total_trades) * 100 if total_trades else 0
    
    # Lucro/Perda
    gross_profit = sum(wins)
    gross_loss = abs(sum(losses))
    net_profit = sum(profits)
    
    # Profit Factor
    profit_factor = gross_profit / gross_loss if gross_loss > 0 else float('inf')
    
    # Expectancy (Esperança Matemática)
    expectancy = mean(profits) if profits else 0
    
    # Risk/Reward
    avg_win = mean(wins) if wins else 0
    avg_loss = abs(mean(losses)) if losses else 0
    risk_reward = avg_win / avg_loss if avg_loss > 0 else float('inf')
    
    # Drawdown
    balance = initial_deposit
    peak = initial_deposit
    max_dd = 0
    max_dd_pct = 0
    
    for p in profits:
        balance += p
        if balance > peak:
            peak = balance
        dd = peak - balance
        dd_pct = (dd / peak) * 100
        if dd > max_dd:
            max_dd = dd
            max_dd_pct = dd_pct
    
    # Sequências
    max_consec_losses = 0
    max_consec_wins = 0
    current_losses = 0
    current_wins = 0
    
    for p in profits:
        if p < 0:
            current_losses += 1
            current_wins = 0
            max_consec_losses = max(max_consec_losses, current_losses)
        else:
            current_wins += 1
            current_losses = 0
            max_consec_wins = max(max_consec_wins, current_wins)
    
    # Razões de fechamento
    close_reasons = defaultdict(int)
    for t in trades:
        close_reasons[t.close_reason] += 1
    
    # Análise de SL/TP
    sl_distances = [t.sl_distance_pips for t in trades]
    tp_distances = [t.tp_distance_pips for t in trades]
    
    # Análise por resultado
    win_durations = [(t.close_time - t.open_time).total_seconds() / 3600 for t in trades if t.profit > 0]
    loss_durations = [(t.close_time - t.open_time).total_seconds() / 3600 for t in trades if t.profit < 0]
    
    return {
        'total_trades': total_trades,
        'win_count': win_count,
        'loss_count': loss_count,
        'win_rate': win_rate,
        'gross_profit': gross_profit,
        'gross_loss': gross_loss,
        'net_profit': net_profit,
        'profit_factor': profit_factor,
        'expectancy': expectancy,
        'avg_win': avg_win,
        'avg_loss': avg_loss,
        'risk_reward': risk_reward,
        'max_drawdown': max_dd,
        'max_drawdown_pct': max_dd_pct,
        'final_balance': initial_deposit + net_profit,
        'return_pct': (net_profit / initial_deposit) * 100,
        'max_consec_losses': max_consec_losses,
        'max_consec_wins': max_consec_wins,
        'close_reasons': dict(close_reasons),
        'avg_sl_distance': mean(sl_distances) if sl_distances else 0,
        'avg_tp_distance': mean(tp_distances) if tp_distances else 0,
        'avg_win_duration_hrs': mean(win_durations) if win_durations else 0,
        'avg_loss_duration_hrs': mean(loss_durations) if loss_durations else 0,
        'trades': trades,
    }

def identify_problems(stats: dict) -> list[dict]:
    """Identifica problemas específicos baseados nas estatísticas"""
    problems = []
    
    # Problema 1: Profit Factor < 1 (perda garantida)
    if stats['profit_factor'] < 1.0:
        problems.append({
            'severity': 'CRÍTICO',
            'issue': 'Profit Factor < 1.0',
            'value': f"PF = {stats['profit_factor']:.2f}",
            'impact': 'O EA perde dinheiro sistematicamente. Para cada $1 de lucro bruto, há mais de $1 de perda.',
            'cause': 'As perdas são maiores que os ganhos por trade.',
        })
    
    # Problema 2: Risk/Reward invertido
    if stats['risk_reward'] < 1.0:
        problems.append({
            'severity': 'CRÍTICO',
            'issue': 'Risk/Reward Invertido',
            'value': f"R:R = 1:{1/stats['risk_reward']:.2f} (Média Win=${stats['avg_win']:.2f} vs Loss=${stats['avg_loss']:.2f})",
            'impact': 'Trades vencedores lucram menos que trades perdedores perdem.',
            'cause': 'Trailing Stop fecha wins cedo demais. Losses atingem SL completo.',
        })
    
    # Problema 3: Expectância negativa
    if stats['expectancy'] < 0:
        problems.append({
            'severity': 'CRÍTICO',
            'issue': 'Expectância Negativa',
            'value': f"EV = ${stats['expectancy']:.3f} por trade",
            'impact': 'Cada trade executado perde dinheiro em média.',
            'cause': 'Combinação de R:R ruim + padrões de saída assimétricos.',
        })
    
    # Problema 4: Todas as saídas por Stop Loss
    close_reasons = stats.get('close_reasons', {})
    if 'Stop Loss' in close_reasons:
        sl_pct = (close_reasons['Stop Loss'] / stats['total_trades']) * 100
        if sl_pct > 90:
            problems.append({
                'severity': 'ALTO',
                'issue': 'Todas as Saídas via Stop Loss',
                'value': f"{sl_pct:.0f}% dos trades fecham por SL",
                'impact': 'Take Profit nunca é atingido. Wins são protegidos por trailing mas fecham cedo.',
                'cause': 'Trailing Stop move SL para lucro, mas o TP está muito longe.',
            })
    
    # Problema 5: Win trades com duração menor que loss trades
    if stats['avg_win_duration_hrs'] > 0 and stats['avg_loss_duration_hrs'] > 0:
        if stats['avg_loss_duration_hrs'] > stats['avg_win_duration_hrs'] * 2:
            problems.append({
                'severity': 'ALTO',
                'issue': 'Trades Perdedores Duram Mais',
                'value': f"Win duration: {stats['avg_win_duration_hrs']:.1f}h | Loss duration: {stats['avg_loss_duration_hrs']:.1f}h",
                'impact': 'Deixa perdedores correrem muito tempo, fecha vencedores muito rápido.',
                'cause': 'Trailing Stop agressivo + SL longe do entry.',
            })
    
    return problems

def calculate_optimal_params(stats: dict) -> dict:
    """Calcula parâmetros ótimos baseados na análise"""
    
    # Para ter expectância positiva:
    # EV = (WinRate * AvgWin) - (LossRate * AvgLoss) > 0
    # 
    # Com WinRate = 60% (0.6), precisamos:
    # 0.6 * AvgWin > 0.4 * AvgLoss
    # AvgWin > 0.67 * AvgLoss
    # 
    # Se SL = 300 pontos = ~$3.1 loss
    # AvgWin precisa ser > $2.07 (mínimo)
    # 
    # Para PF > 1.5 (saudável):
    # AvgWin precisa ser > $1.55 * AvgLoss / WinRate = $3.1 * 1.5 / 60% = $7.75
    
    current_loss = stats['avg_loss']
    win_rate = stats['win_rate'] / 100
    loss_rate = 1 - win_rate
    
    # Mínimo para breakeven
    min_win_breakeven = (loss_rate / win_rate) * current_loss if win_rate > 0 else 0
    
    # Para PF = 1.5 (rentável)
    target_pf = 1.5
    min_win_profitable = target_pf * current_loss * loss_rate / win_rate if win_rate > 0 else 0
    
    # Trailing Stop atual está cortando em ~$1
    # Precisa deixar correr até pelo menos $2.07 para breakeven
    
    # Calculando parâmetros sugeridos
    # Se SL = 300 pontos e perda = $3.1, então 1 ponto ≈ $0.0103
    dollar_per_point = current_loss / 300 if current_loss > 0 else 0.01
    
    # Para win = $2.07 (breakeven):
    breakeven_tp_points = min_win_breakeven / dollar_per_point if dollar_per_point > 0 else 200
    
    # Para win = $4.65 (PF=1.5):
    profitable_tp_points = min_win_profitable / dollar_per_point if dollar_per_point > 0 else 450
    
    return {
        'current_avg_win': stats['avg_win'],
        'current_avg_loss': current_loss,
        'current_win_rate': stats['win_rate'],
        'current_rr': stats['risk_reward'],
        'min_win_breakeven': min_win_breakeven,
        'min_win_profitable': min_win_profitable,
        'suggested_trailing_trigger': int(profitable_tp_points * 0.6),  # 60% do TP
        'suggested_trailing_distance': int(profitable_tp_points * 0.4),  # 40% do TP
        'suggested_tp_points': int(profitable_tp_points),
        'suggested_sl_points': 300,  # Manter SL atual
        'reasoning': f"""
Para breakeven com WinRate de {stats['win_rate']:.1f}%:
- Avg Win mínimo: ${min_win_breakeven:.2f}

Para rentabilidade (PF=1.5):
- Avg Win necessário: ${min_win_profitable:.2f}
- TP sugerido: {int(profitable_tp_points)} pontos

Problema atual:
- Trailing ativa em 400 pontos (${400 * dollar_per_point:.2f})
- Mas fecha com lucro de ~$1 porque distance=250 e step=50
- O trail está muito APERTADO, não deixa o trade respirar

Solução:
- Aumentar Trailing Trigger para {int(profitable_tp_points * 0.7)} pontos
- Aumentar Trailing Distance para {int(profitable_tp_points * 0.5)} pontos
- OU reduzir SL para 200 pontos (mantendo mesma % de acerto)
- OU desativar trailing e usar TP fixo a {int(profitable_tp_points)} pontos
"""
    }

def generate_report(stats: dict, problems: list, optimal: dict) -> str:
    """Gera relatório completo em Markdown"""
    
    report = []
    report.append("# 📊 RELATÓRIO DE ANÁLISE FINANCEIRA DO EA FGM TrendRider\n")
    report.append("---\n")
    
    # Resumo Executivo
    report.append("## 🚨 RESUMO EXECUTIVO\n")
    report.append(f"**Status do EA: {'❌ NÃO LUCRATIVO' if stats['net_profit'] < 0 else '✅ LUCRATIVO'}**\n")
    report.append(f"- Depósito Inicial: $100.00")
    report.append(f"- Saldo Final: ${stats['final_balance']:.2f}")
    report.append(f"- Retorno: {stats['return_pct']:.2f}%")
    report.append(f"- Profit Factor: {stats['profit_factor']:.2f}")
    report.append(f"- Expectância: ${stats['expectancy']:.3f}/trade\n")
    
    # Estatísticas Completas
    report.append("## 📈 ESTATÍSTICAS DE TRADING\n")
    report.append("| Métrica | Valor |")
    report.append("|---------|-------|")
    report.append(f"| Total de Trades | {stats['total_trades']} |")
    report.append(f"| Wins | {stats['win_count']} ({stats['win_rate']:.1f}%) |")
    report.append(f"| Losses | {stats['loss_count']} ({100-stats['win_rate']:.1f}%) |")
    report.append(f"| Lucro Bruto | ${stats['gross_profit']:.2f} |")
    report.append(f"| Perda Bruta | -${stats['gross_loss']:.2f} |")
    report.append(f"| Lucro Líquido | ${stats['net_profit']:.2f} |")
    report.append(f"| Profit Factor | {stats['profit_factor']:.2f} |")
    report.append(f"| Média de Win | ${stats['avg_win']:.2f} |")
    report.append(f"| Média de Loss | -${stats['avg_loss']:.2f} |")
    report.append(f"| Risk/Reward | 1:{1/stats['risk_reward']:.2f} |")
    report.append(f"| Max Drawdown | ${stats['max_drawdown']:.2f} ({stats['max_drawdown_pct']:.2f}%) |")
    report.append(f"| Max Perdas Consecutivas | {stats['max_consec_losses']} |")
    report.append(f"| Max Wins Consecutivos | {stats['max_consec_wins']} |\n")
    
    # Razões de Fechamento
    report.append("### Razões de Fechamento\n")
    for reason, count in stats.get('close_reasons', {}).items():
        pct = (count / stats['total_trades']) * 100
        report.append(f"- {reason}: {count} trades ({pct:.1f}%)")
    report.append("")
    
    # Problemas Identificados
    report.append("## 🔴 PROBLEMAS IDENTIFICADOS\n")
    for i, p in enumerate(problems, 1):
        report.append(f"### Problema #{i}: {p['issue']}")
        report.append(f"- **Severidade:** {p['severity']}")
        report.append(f"- **Valor:** {p['value']}")
        report.append(f"- **Impacto:** {p['impact']}")
        report.append(f"- **Causa:** {p['cause']}\n")
    
    # Análise Matemática
    report.append("## 🧮 ANÁLISE MATEMÁTICA\n")
    report.append("### Fórmula da Expectância")
    report.append("```")
    report.append(f"EV = (WinRate × AvgWin) - (LossRate × AvgLoss)")
    report.append(f"EV = ({stats['win_rate']:.1f}% × ${stats['avg_win']:.2f}) - ({100-stats['win_rate']:.1f}% × ${stats['avg_loss']:.2f})")
    report.append(f"EV = ${stats['win_rate']/100 * stats['avg_win']:.3f} - ${(100-stats['win_rate'])/100 * stats['avg_loss']:.3f}")
    report.append(f"EV = ${stats['expectancy']:.3f} por trade")
    report.append("```\n")
    
    report.append("### Fórmula do Profit Factor")
    report.append("```")
    report.append(f"PF = Lucro Bruto / Perda Bruta")
    report.append(f"PF = ${stats['gross_profit']:.2f} / ${stats['gross_loss']:.2f}")
    report.append(f"PF = {stats['profit_factor']:.2f}")
    report.append("```")
    report.append("**PF < 1.0 significa que o EA perde mais do que ganha!**\n")
    
    # Recomendações
    report.append("## ✅ RECOMENDAÇÕES\n")
    report.append(optimal['reasoning'])
    
    report.append("\n### Parâmetros Sugeridos")
    report.append(f"- **TP Target:** {optimal['suggested_tp_points']} pontos (lucro alvo: ${optimal['min_win_profitable']:.2f})")
    report.append(f"- **SL:** {optimal['suggested_sl_points']} pontos (manter)")
    report.append(f"- **Trailing Trigger:** {optimal['suggested_trailing_trigger']} pontos")
    report.append(f"- **Trailing Distance:** {optimal['suggested_trailing_distance']} pontos")
    
    report.append("\n### Opções de Correção")
    report.append("1. **Opção A - Aumentar Trailing:** Deixar lucro correr mais antes de proteger")
    report.append("2. **Opção B - TP Fixo:** Desativar trailing, usar TP fixo mais agressivo")
    report.append("3. **Opção C - Reduzir SL:** Usar SL menor (200pts) para manter R:R")
    report.append("4. **Opção D - Híbrido:** SL=200, TP=400, Trail apenas após +300pts\n")
    
    # Lista de trades
    report.append("## 📋 LISTA DE TRADES\n")
    report.append("| # | Data | Dir | Entry | SL | TP | Profit | Reason |")
    report.append("|---|------|-----|-------|----|----|--------|--------|")
    for i, t in enumerate(stats.get('trades', []), 1):
        emoji = "✅" if t.profit > 0 else "❌"
        report.append(f"| {i} | {t.open_time.strftime('%Y-%m-%d %H:%M')} | {t.direction} | {t.entry_price:.3f} | {t.sl:.3f} | {t.tp:.3f} | {emoji} ${t.profit:.2f} | {t.close_reason} |")
    
    return "\n".join(report)

def main():
    print("=" * 60)
    print("ANÁLISE COMPLETA DO EA FGM TrendRider")
    print("=" * 60)
    
    # Ler log
    if not LOG_PATH.exists():
        print(f"❌ Erro: Log não encontrado em {LOG_PATH}")
        return 1
    
    print(f"\n📂 Lendo log: {LOG_PATH.name}")
    content = read_log(LOG_PATH)
    lines = content.splitlines()
    print(f"   {len(lines):,} linhas no log")
    
    # Parsear trades
    print("\n🔍 Analisando trades...")
    trades = parse_trades(lines)
    print(f"   {len(trades)} trades encontrados")
    
    if not trades:
        print("❌ Nenhum trade encontrado no log!")
        return 1
    
    # Análise estatística
    print("\n📊 Calculando estatísticas...")
    stats = analyze_trades(trades, initial_deposit=100.0)
    
    # Identificar problemas
    print("\n🔴 Identificando problemas...")
    problems = identify_problems(stats)
    print(f"   {len(problems)} problemas críticos encontrados")
    
    # Calcular parâmetros ótimos
    print("\n🧮 Calculando parâmetros ótimos...")
    optimal = calculate_optimal_params(stats)
    
    # Gerar relatório
    print("\n📝 Gerando relatório...")
    report = generate_report(stats, problems, optimal)
    
    # Salvar relatório
    report_path = LOG_PATH.parent / "problema_identificado_relatorio.md"
    report_path.write_text(report, encoding='utf-8')
    print(f"   Relatório salvo em: {report_path.name}")
    
    # Imprimir resumo no console
    print("\n" + "=" * 60)
    print("RESUMO DOS PROBLEMAS")
    print("=" * 60)
    for p in problems:
        print(f"\n❌ [{p['severity']}] {p['issue']}")
        print(f"   → {p['value']}")
        print(f"   → {p['cause']}")
    
    print("\n" + "=" * 60)
    print("SOLUÇÃO RECOMENDADA")
    print("=" * 60)
    print(f"\nO EA tem WinRate de {stats['win_rate']:.1f}% mas perde dinheiro porque:")
    print(f"  • Média de WIN: ${stats['avg_win']:.2f} (muito baixo)")
    print(f"  • Média de LOSS: -${stats['avg_loss']:.2f} (alto)")
    print(f"  • R:R Atual: 1:{1/stats['risk_reward']:.2f} (invertido)")
    print(f"\nPara ser lucrativo com 60% WinRate:")
    print(f"  • Média WIN mínima: ${optimal['min_win_breakeven']:.2f} (breakeven)")
    print(f"  • Média WIN ideal: ${optimal['min_win_profitable']:.2f} (PF=1.5)")
    print(f"\nAjuste os parâmetros de Trailing Stop:")
    print(f"  • Trailing Trigger: 400 → {optimal['suggested_trailing_trigger']} pontos")
    print(f"  • Trailing Distance: 250 → {optimal['suggested_trailing_distance']} pontos")
    
    return 0

if __name__ == "__main__":
    exit(main())
