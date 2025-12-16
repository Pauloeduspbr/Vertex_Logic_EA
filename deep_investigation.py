#!/usr/bin/env python3
"""
Análise PROFUNDA do EA - Investigação de Problemas Estruturais

Foco em:
1. Sincronização de indicadores
2. Qualidade dos sinais
3. Filtros funcionando corretamente
4. Padrões de trades perdedores
"""

import re
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from collections import defaultdict
from statistics import mean, stdev
import json

LOG_PATH = Path(__file__).parent / "20251216.log"

@dataclass
class Signal:
    time: datetime
    bar: int
    entry: int  # 1=BUY, -1=SELL
    strength: int
    confluence: float

@dataclass
class FilterCheck:
    time: datetime
    filter_name: str
    passed: bool
    details: str

@dataclass
class TradeEntry:
    time: datetime
    direction: str
    entry_price: float
    sl: float
    tp: float
    volume: float
    
    # Context at entry
    confluence: float = 0.0
    strength: int = 0
    obv_hist1: float = 0.0
    obv_hist2: float = 0.0
    rsi: float = 0.0
    rsi_ma: float = 0.0
    slope: float = 0.0
    phase: int = 0
    regime: str = ""
    ema200_ok: bool = True

@dataclass 
class TradeClose:
    time: datetime
    profit: float
    reason: str
    outcome: str  # WIN/LOSS

@dataclass
class BadEntry:
    time: datetime
    profit: float
    close_reason: str
    direction: str
    regime: str
    strength: int
    confluence: float
    sl_pts: float
    risk_pct: float
    spread: float
    slope: float
    volume: int
    phase: int
    ema200_ok: bool
    rsi: float
    rsi_ma: float
    obv: int

def read_log(path: Path) -> str:
    data = path.read_bytes()
    if data.startswith(b'\xff\xfe'):
        return data.decode('utf-16-le')
    try:
        return data.decode('utf-8')
    except:
        return data.decode('latin-1')

def parse_signals(lines: list[str]) -> list[Signal]:
    """Extrai todos os sinais detectados"""
    pattern = re.compile(
        r'(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}).*Sinal detectado!.*Bar=(\d+),\s+Entry=(-?\d+),\s+Strength=(-?\d+),\s+Confluence=([0-9.]+)%'
    )
    signals = []
    for line in lines:
        m = pattern.search(line)
        if m:
            signals.append(Signal(
                time=datetime.strptime(m.group(1), '%Y.%m.%d %H:%M:%S'),
                bar=int(m.group(2)),
                entry=int(m.group(3)),
                strength=int(m.group(4)),
                confluence=float(m.group(5))
            ))
    return signals

def parse_filter_blocks(lines: list[str]) -> list[FilterCheck]:
    """Extrai bloqueios de filtros"""
    pattern = re.compile(
        r'(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}).*FILTRO BLOQUEOU:\s+(.+)'
    )
    blocks = []
    for line in lines:
        m = pattern.search(line)
        if m:
            blocks.append(FilterCheck(
                time=datetime.strptime(m.group(1), '%Y.%m.%d %H:%M:%S'),
                filter_name=m.group(2).split(':')[0].strip(),
                passed=False,
                details=m.group(2)
            ))
    return blocks

def parse_obv_macd_debug(lines: list[str]) -> list[dict]:
    """Extrai dados de debug do OBV MACD"""
    pattern = re.compile(
        r'(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}).*\[OBV MACD DEBUG\].*Bar1:\s+Hist=([0-9.-]+).*Bar2:\s+Hist=([0-9.-]+).*Color=(\d+).*Threshold=([0-9.-]+)'
    )
    data = []
    for line in lines:
        m = pattern.search(line)
        if m:
            data.append({
                'time': datetime.strptime(m.group(1), '%Y.%m.%d %H:%M:%S'),
                'hist1': float(m.group(2)),
                'hist2': float(m.group(3)),
                'color': int(m.group(4)),
                'threshold': float(m.group(5))
            })
    return data

def parse_bad_entries(lines: list[str]) -> list[BadEntry]:
    """Extrai entradas ruins com diagnóstico completo"""
    pattern = re.compile(
        r'(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}).*BAD ENTRY.*Profit=(-?[0-9.]+).*Close=([^|]+)\|.*Dir=(\w+).*Regime=([^|]+)\|.*F=(\d+).*Conf=([0-9.]+)%.*SLpts=([0-9.]+).*Risk=([0-9.]+)%.*Spread=([0-9.]+).*Slope=(-?[0-9.]+).*Vol=(\d+)/.*Phase=(-?\d+).*EMA200=(\w+).*RSI=([0-9.]+)/MA([0-9.]+).*OBV=(\d+)'
    )
    entries = []
    for line in lines:
        m = pattern.search(line)
        if m:
            entries.append(BadEntry(
                time=datetime.strptime(m.group(1), '%Y.%m.%d %H:%M:%S'),
                profit=float(m.group(2)),
                close_reason=m.group(3).strip(),
                direction=m.group(4),
                regime=m.group(5).strip(),
                strength=int(m.group(6)),
                confluence=float(m.group(7)),
                sl_pts=float(m.group(8)),
                risk_pct=float(m.group(9)),
                spread=float(m.group(10)),
                slope=float(m.group(11)),
                volume=int(m.group(12)),
                phase=int(m.group(13)),
                ema200_ok=(m.group(14) == 'OK'),
                rsi=float(m.group(15)),
                rsi_ma=float(m.group(16)),
                obv=int(m.group(17))
            ))
    return entries

def parse_trades(lines: list[str]) -> tuple[list[TradeEntry], list[TradeClose]]:
    """Extrai trades abertos e fechados"""
    open_pattern = re.compile(
        r'(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}).*\[INFO\]\s+TRADE:\s+(BUY|SELL)\s+@\s+([0-9.]+).*Vol:\s+([0-9.]+).*SL:\s+([0-9.]+).*TP:\s+([0-9.]+)'
    )
    close_pattern = re.compile(
        r'(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}).*TRADE CLOSED:\s+(WIN|LOSS).*Profit:\s+(-?[0-9.]+).*Raz[aã]o:\s+(.+)'
    )
    
    entries = []
    closes = []
    
    for line in lines:
        m = open_pattern.search(line)
        if m:
            entries.append(TradeEntry(
                time=datetime.strptime(m.group(1), '%Y.%m.%d %H:%M:%S'),
                direction=m.group(2),
                entry_price=float(m.group(3)),
                volume=float(m.group(4)),
                sl=float(m.group(5)),
                tp=float(m.group(6))
            ))
            continue
        
        m = close_pattern.search(line)
        if m:
            closes.append(TradeClose(
                time=datetime.strptime(m.group(1), '%Y.%m.%d %H:%M:%S'),
                outcome=m.group(2),
                profit=float(m.group(3)),
                reason=m.group(4).strip()
            ))
    
    return entries, closes

def analyze_indicator_health(obv_data: list[dict], bad_entries: list[BadEntry]) -> dict:
    """Analisa se os indicadores estão funcionando corretamente"""
    
    issues = []
    
    # OBV MACD sempre zero?
    if obv_data:
        zero_count = sum(1 for d in obv_data if d['hist1'] == 0 and d['hist2'] == 0)
        zero_pct = (zero_count / len(obv_data)) * 100
        if zero_pct > 90:
            issues.append({
                'severity': 'CRÍTICO',
                'indicator': 'OBV MACD',
                'issue': f'Histograma sempre ZERO ({zero_pct:.0f}% das leituras)',
                'impact': 'Indicador não está calculando valores - não filtra nada',
                'cause': 'Indicador não inicializado ou parâmetros incorretos'
            })
    
    # RSI sempre 50?
    if bad_entries:
        rsi_50_count = sum(1 for e in bad_entries if e.rsi == 50.0)
        if rsi_50_count == len(bad_entries) and len(bad_entries) > 2:
            issues.append({
                'severity': 'CRÍTICO',
                'indicator': 'RSI',
                'issue': f'RSI sempre 50.0 em {len(bad_entries)} bad entries',
                'impact': 'RSI não está sendo calculado - valor neutro default',
                'cause': 'Indicador RSI não inicializado ou handle inválido'
            })
        
        # Volume sempre 0?
        obv_zero = sum(1 for e in bad_entries if e.obv == 0)
        if obv_zero == len(bad_entries):
            issues.append({
                'severity': 'ALTO',
                'indicator': 'OBV',
                'issue': f'OBV sempre 0 em todos os bad entries',
                'impact': 'Filtro de volume não funciona',
                'cause': 'Indicador OBV não inicializado'
            })
    
    return {
        'obv_readings': len(obv_data),
        'obv_zero_count': sum(1 for d in obv_data if d['hist1'] == 0) if obv_data else 0,
        'issues': issues
    }

def analyze_signal_quality(signals: list[Signal], entries: list[TradeEntry], 
                          closes: list[TradeClose], bad_entries: list[BadEntry]) -> dict:
    """Analisa qualidade dos sinais vs resultados"""
    
    # Contar sinais por força
    by_strength = defaultdict(lambda: {'count': 0, 'traded': 0, 'wins': 0, 'losses': 0})
    
    for s in signals:
        strength = abs(s.strength)
        by_strength[strength]['count'] += 1
    
    # Match trades com sinais (aproximado)
    for i, (entry, close) in enumerate(zip(entries, closes)):
        # Find nearest signal before entry
        for s in reversed(signals):
            if s.time <= entry.time:
                strength = abs(s.strength)
                by_strength[strength]['traded'] += 1
                if close.outcome == 'WIN':
                    by_strength[strength]['wins'] += 1
                else:
                    by_strength[strength]['losses'] += 1
                break
    
    # Calcular win rate por força
    result = {}
    for strength, data in sorted(by_strength.items()):
        traded = data['traded']
        wr = (data['wins'] / traded * 100) if traded > 0 else 0
        result[f'F{strength}'] = {
            'signals': data['count'],
            'traded': traded,
            'wins': data['wins'],
            'losses': data['losses'],
            'win_rate': wr,
            'conversion': (traded / data['count'] * 100) if data['count'] > 0 else 0
        }
    
    return result

def analyze_filter_effectiveness(blocks: list[FilterCheck], 
                                 entries: list[TradeEntry],
                                 closes: list[TradeClose]) -> dict:
    """Analisa se filtros estão bloqueando trades bons ou ruins"""
    
    # Contar bloqueios por tipo
    by_filter = defaultdict(int)
    for b in blocks:
        by_filter[b.filter_name] += 1
    
    total_blocks = len(blocks)
    total_trades = len(entries)
    
    # Trade results
    wins = sum(1 for c in closes if c.outcome == 'WIN')
    losses = sum(1 for c in closes if c.outcome == 'LOSS')
    
    return {
        'total_signals_blocked': total_blocks,
        'total_trades_taken': total_trades,
        'trades_win': wins,
        'trades_loss': losses,
        'win_rate': (wins / total_trades * 100) if total_trades > 0 else 0,
        'blocks_by_filter': dict(by_filter),
        'pass_rate': (total_trades / (total_trades + total_blocks) * 100) if (total_trades + total_blocks) > 0 else 0
    }

def analyze_trade_patterns(bad_entries: list[BadEntry]) -> dict:
    """Analisa padrões em trades perdedores"""
    
    if not bad_entries:
        return {}
    
    patterns = {
        'by_regime': defaultdict(lambda: {'count': 0, 'total_loss': 0}),
        'by_direction': defaultdict(lambda: {'count': 0, 'total_loss': 0}),
        'by_phase': defaultdict(lambda: {'count': 0, 'total_loss': 0}),
        'by_strength': defaultdict(lambda: {'count': 0, 'total_loss': 0}),
        'slope_stats': {'positive': 0, 'negative': 0, 'total': 0},
    }
    
    slopes = []
    risk_pcts = []
    
    for e in bad_entries:
        patterns['by_regime'][e.regime]['count'] += 1
        patterns['by_regime'][e.regime]['total_loss'] += abs(e.profit)
        
        patterns['by_direction'][e.direction]['count'] += 1
        patterns['by_direction'][e.direction]['total_loss'] += abs(e.profit)
        
        patterns['by_phase'][e.phase]['count'] += 1
        patterns['by_phase'][e.phase]['total_loss'] += abs(e.profit)
        
        patterns['by_strength'][f'F{e.strength}']['count'] += 1
        patterns['by_strength'][f'F{e.strength}']['total_loss'] += abs(e.profit)
        
        if e.slope > 0:
            patterns['slope_stats']['positive'] += 1
        else:
            patterns['slope_stats']['negative'] += 1
        patterns['slope_stats']['total'] += 1
        
        slopes.append(e.slope)
        risk_pcts.append(e.risk_pct)
    
    # Converter defaultdicts para dicts
    for key in patterns:
        if isinstance(patterns[key], defaultdict):
            patterns[key] = dict(patterns[key])
    
    patterns['avg_slope'] = mean(slopes) if slopes else 0
    patterns['avg_risk_pct'] = mean(risk_pcts) if risk_pcts else 0
    patterns['total_bad_entries'] = len(bad_entries)
    
    return patterns

def generate_investigation_report(
    signals: list, blocks: list, obv_data: list,
    entries: list, closes: list, bad_entries: list
) -> str:
    """Gera relatório de investigação profunda"""
    
    indicator_health = analyze_indicator_health(obv_data, bad_entries)
    signal_quality = analyze_signal_quality(signals, entries, closes, bad_entries)
    filter_stats = analyze_filter_effectiveness(blocks, entries, closes)
    trade_patterns = analyze_trade_patterns(bad_entries)
    
    lines = []
    lines.append("# 🔍 INVESTIGAÇÃO PROFUNDA DO EA FGM TrendRider\n")
    lines.append("---\n")
    
    # Resumo de Problemas Críticos
    lines.append("## 🚨 PROBLEMAS CRÍTICOS DETECTADOS\n")
    
    for issue in indicator_health.get('issues', []):
        lines.append(f"### [{issue['severity']}] {issue['indicator']}")
        lines.append(f"- **Problema:** {issue['issue']}")
        lines.append(f"- **Impacto:** {issue['impact']}")
        lines.append(f"- **Causa provável:** {issue['cause']}\n")
    
    # Saúde dos Indicadores
    lines.append("## 📊 SAÚDE DOS INDICADORES\n")
    lines.append(f"- OBV MACD leituras: {indicator_health['obv_readings']}")
    lines.append(f"- OBV MACD retornando ZERO: {indicator_health['obv_zero_count']} vezes")
    if indicator_health['obv_readings'] > 0:
        zero_pct = (indicator_health['obv_zero_count'] / indicator_health['obv_readings']) * 100
        lines.append(f"- **Taxa de zeros: {zero_pct:.1f}%** {'⚠️ PROBLEMA!' if zero_pct > 50 else ''}\n")
    
    # Qualidade dos Sinais
    lines.append("## 📈 QUALIDADE DOS SINAIS POR FORÇA\n")
    lines.append("| Força | Sinais | Trades | Wins | Losses | WinRate | Conversão |")
    lines.append("|-------|--------|--------|------|--------|---------|-----------|")
    for strength, data in sorted(signal_quality.items()):
        lines.append(
            f"| {strength} | {data['signals']} | {data['traded']} | {data['wins']} | {data['losses']} | {data['win_rate']:.1f}% | {data['conversion']:.1f}% |"
        )
    
    # Efetividade dos Filtros
    lines.append("\n## 🔒 EFETIVIDADE DOS FILTROS\n")
    lines.append(f"- Sinais bloqueados: {filter_stats['total_signals_blocked']}")
    lines.append(f"- Trades executados: {filter_stats['total_trades_taken']}")
    lines.append(f"- Taxa de passagem: {filter_stats['pass_rate']:.1f}%")
    lines.append(f"- Win Rate nos trades executados: {filter_stats['win_rate']:.1f}%\n")
    
    lines.append("### Bloqueios por Filtro")
    for filter_name, count in sorted(filter_stats['blocks_by_filter'].items(), key=lambda x: -x[1]):
        lines.append(f"- {filter_name}: {count} bloqueios")
    
    # Padrões de Trades Perdedores
    lines.append("\n## 📉 PADRÕES NOS TRADES PERDEDORES\n")
    if trade_patterns:
        lines.append(f"- Total de bad entries analisados: {trade_patterns['total_bad_entries']}")
        lines.append(f"- Risco médio por trade: {trade_patterns['avg_risk_pct']:.1f}%")
        lines.append(f"- Slope médio: {trade_patterns['avg_slope']:.5f}")
        
        slope_stats = trade_patterns.get('slope_stats', {})
        if slope_stats.get('total', 0) > 0:
            pos_pct = (slope_stats['positive'] / slope_stats['total']) * 100
            lines.append(f"- Slope positivo: {slope_stats['positive']} ({pos_pct:.0f}%)")
            lines.append(f"- Slope negativo: {slope_stats['negative']} ({100-pos_pct:.0f}%)")
        
        lines.append("\n### Por Regime de Mercado")
        for regime, data in sorted(trade_patterns.get('by_regime', {}).items()):
            lines.append(f"- {regime}: {data['count']} trades, perda total ${data['total_loss']:.2f}")
        
        lines.append("\n### Por Direção")
        for direction, data in sorted(trade_patterns.get('by_direction', {}).items()):
            lines.append(f"- {direction}: {data['count']} trades, perda total ${data['total_loss']:.2f}")
        
        lines.append("\n### Por Força")
        for strength, data in sorted(trade_patterns.get('by_strength', {}).items()):
            lines.append(f"- {strength}: {data['count']} trades, perda total ${data['total_loss']:.2f}")
    
    # Recomendações
    lines.append("\n## ✅ RECOMENDAÇÕES DE CORREÇÃO\n")
    
    for issue in indicator_health.get('issues', []):
        if 'OBV MACD' in issue['indicator']:
            lines.append("### 1. Corrigir OBV MACD")
            lines.append("```")
            lines.append("O indicador OBV MACD está retornando ZERO em todas as leituras.")
            lines.append("Possíveis causas:")
            lines.append("  - Handle do indicador inválido")
            lines.append("  - Indicador não compilado/instalado corretamente")
            lines.append("  - Parâmetros de período incompatíveis com dados")
            lines.append("```")
            lines.append("")
        
        if 'RSI' in issue['indicator']:
            lines.append("### 2. Verificar RSI")
            lines.append("```")
            lines.append("RSI está retornando valor fixo 50.0 (valor neutro).")
            lines.append("Isso indica que o indicador não está calculando.")
            lines.append("Verificar inicialização do handle RSI em CFilters.mqh")
            lines.append("```")
            lines.append("")
    
    return "\n".join(lines)

def main():
    global LOG_PATH
    print("=" * 70)
    print("INVESTIGAÇÃO PROFUNDA DO EA FGM TrendRider")
    print("=" * 70)
    
    if not LOG_PATH.exists():
        print(f"❌ Log não encontrado: {LOG_PATH}")
        # Tentar alternativa
        alt_path = Path(__file__).parent / "20251216.log"
        if alt_path.exists():
            LOG_PATH = alt_path
            print(f"✓ Usando log alternativo: {LOG_PATH}")
        else:
            return 1
    
    print(f"\n📂 Lendo: {LOG_PATH.name}")
    content = read_log(LOG_PATH)
    lines = content.splitlines()
    print(f"   {len(lines):,} linhas")
    
    # Parse tudo
    print("\n🔍 Analisando...")
    signals = parse_signals(lines)
    print(f"   {len(signals)} sinais detectados")
    
    blocks = parse_filter_blocks(lines)
    print(f"   {len(blocks)} bloqueios de filtro")
    
    obv_data = parse_obv_macd_debug(lines)
    print(f"   {len(obv_data)} leituras OBV MACD")
    
    entries, closes = parse_trades(lines)
    print(f"   {len(entries)} trades abertos, {len(closes)} fechados")
    
    bad_entries = parse_bad_entries(lines)
    print(f"   {len(bad_entries)} bad entries")
    
    # Gerar relatório
    report = generate_investigation_report(
        signals, blocks, obv_data, entries, closes, bad_entries
    )
    
    report_path = LOG_PATH.parent / "investigacao_profunda.md"
    report_path.write_text(report, encoding='utf-8')
    print(f"\n📝 Relatório: {report_path.name}")
    
    # Análise rápida no console
    print("\n" + "=" * 70)
    print("PROBLEMAS ENCONTRADOS")
    print("=" * 70)
    
    indicator_health = analyze_indicator_health(obv_data, bad_entries)
    for issue in indicator_health.get('issues', []):
        print(f"\n❌ [{issue['severity']}] {issue['indicator']}")
        print(f"   {issue['issue']}")
        print(f"   → {issue['cause']}")
    
    if entries and closes:
        wins = sum(1 for c in closes if c.outcome == 'WIN')
        losses = sum(1 for c in closes if c.outcome == 'LOSS')
        win_profits = [c.profit for c in closes if c.outcome == 'WIN']
        loss_profits = [c.profit for c in closes if c.outcome == 'LOSS']
        
        print(f"\n📊 ESTATÍSTICAS DOS TRADES")
        print(f"   Trades: {len(entries)} (W:{wins} L:{losses})")
        print(f"   WinRate: {wins/len(entries)*100:.1f}%")
        if win_profits:
            print(f"   Avg Win: ${mean(win_profits):.2f}")
        if loss_profits:
            print(f"   Avg Loss: ${mean(loss_profits):.2f}")
    
    return 0

if __name__ == "__main__":
    exit(main())
