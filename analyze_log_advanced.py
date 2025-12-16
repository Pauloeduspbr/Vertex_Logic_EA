#!/usr/bin/env python3
"""Advanced MT5 tester log analyzer (stdlib-only).

Focuses on extracting the EA's own structured lines:
- "[INFO] TRADE: BUY @ ... | Vol: ... | SL: ... | TP: ..."
- "[INFO] TRADE CLOSED: WIN|LOSS | Profit: ... | Razão: ..."
- "[INFO] Sinal detectado! ... Strength=..., Confluence=...%"

It then produces:
- trade list (paired open/close; assumes 1 position at a time)
- equity curve (closed PnL)
- max drawdown
- PF, expectancy, winrate
- loss streaks
- breakdown by day / hour / strength

No third-party dependencies are required.
"""

from __future__ import annotations

import argparse
import csv
import re
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from statistics import mean, pstdev
from typing import Iterable


DEFAULT_LOG_PATH = Path(__file__).resolve().parent / "20251215.log"
DEFAULT_REPORT_PATH = Path(__file__).resolve().parent / "financial_analysis_report_advanced.md"
DEFAULT_TRADES_CSV = Path(__file__).resolve().parent / "trades_20251215.csv"


@dataclass(frozen=True)
class SignalEvent:
    ts: datetime
    strength: int
    entry: int
    confluence_pct: float


@dataclass(frozen=True)
class TradeOpen:
    ts: datetime
    side: str  # BUY/SELL
    price: float
    volume: float
    sl: float
    tp: float


@dataclass(frozen=True)
class TradeClose:
    ts: datetime
    outcome: str  # WIN/LOSS
    profit: float
    reason: str


@dataclass(frozen=True)
class Trade:
    open_ts: datetime
    close_ts: datetime
    side: str
    volume: float
    open_price: float
    sl: float
    tp: float
    profit: float
    outcome: str
    reason: str
    duration_min: float
    strength: int | None
    confluence_pct: float | None
    entry: int | None


def _parse_lines(log_path: Path) -> list[str]:
    data = log_path.read_bytes()
    # MT5 tester logs are often UTF-16LE with BOM (especially on Wine/Windows).
    if data.startswith(b"\xff\xfe") or data.startswith(b"\xfe\xff"):
        text = data.decode("utf-16", errors="ignore")
    else:
        # Try UTF-8 first, then fall back.
        try:
            text = data.decode("utf-8")
        except UnicodeDecodeError:
            text = data.decode("latin-1", errors="ignore")
    return text.splitlines()


def parse_initial_deposit(lines: Iterable[str]) -> float | None:
    for line in lines:
        m = re.search(r"initial deposit\s+(\d+(?:\.\d+)?)", line, re.IGNORECASE)
        if m:
            return float(m.group(1))
    return None


OPEN_RE = re.compile(
    r"\t(?P<ts>\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})\s+\[\d{2}:\d{2}:\d{2}\]\s+\[INFO\]\s+TRADE:\s+(?P<side>BUY|SELL)\s+@\s+(?P<price>[0-9.]+)\s+\|\s+Vol:\s+(?P<vol>[0-9.]+)\s+\|\s+SL:\s+(?P<sl>[0-9.]+)\s+\|\s+TP:\s+(?P<tp>[0-9.]+)"
)

CLOSE_RE = re.compile(
    r"\t(?P<ts>\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})\s+\[\d{2}:\d{2}:\d{2}\]\s+\[INFO\]\s+TRADE CLOSED:\s+(?P<outcome>WIN|LOSS)\s+\|\s+Profit:\s+(?P<profit>-?[0-9.]+)\s+\|\s+Raz[aã]o:\s+(?P<reason>.*)$"
)

SIGNAL_RE = re.compile(
    r"\t(?P<ts>\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}).*\[INFO\]\s+Sinal detectado!\s+Bar=\d+,\s+Entry=(?P<entry>-?\d+),\s+Strength=(?P<strength>-?\d+),\s+Confluence=(?P<conf>[0-9.]+)%"
)


def parse_events(lines: Iterable[str]) -> tuple[list[SignalEvent], list[TradeOpen], list[TradeClose]]:
    signals: list[SignalEvent] = []
    opens: list[TradeOpen] = []
    closes: list[TradeClose] = []

    for line in lines:
        ms = SIGNAL_RE.search(line)
        if ms:
            ts = datetime.strptime(ms.group("ts"), "%Y.%m.%d %H:%M:%S")
            signals.append(
                SignalEvent(
                    ts=ts,
                    strength=int(ms.group("strength")),
                    entry=int(ms.group("entry")),
                    confluence_pct=float(ms.group("conf")),
                )
            )
            continue

        mo = OPEN_RE.search(line)
        if mo:
            ts = datetime.strptime(mo.group("ts"), "%Y.%m.%d %H:%M:%S")
            opens.append(
                TradeOpen(
                    ts=ts,
                    side=mo.group("side"),
                    price=float(mo.group("price")),
                    volume=float(mo.group("vol")),
                    sl=float(mo.group("sl")),
                    tp=float(mo.group("tp")),
                )
            )
            continue

        mc = CLOSE_RE.search(line)
        if mc:
            ts = datetime.strptime(mc.group("ts"), "%Y.%m.%d %H:%M:%S")
            closes.append(
                TradeClose(
                    ts=ts,
                    outcome=mc.group("outcome"),
                    profit=float(mc.group("profit")),
                    reason=mc.group("reason").strip(),
                )
            )
            continue

    return signals, opens, closes


def _nearest_prior_signal(signals_sorted: list[SignalEvent], t: datetime, max_delta_seconds: int = 60 * 60) -> SignalEvent | None:
    """Pick the most recent signal at/before time t within a window."""
    # Signals are relatively sparse; linear scan backwards from end is OK.
    # (Log size is ~50k lines; events count is much smaller.)
    for s in reversed(signals_sorted):
        if s.ts <= t:
            if (t - s.ts).total_seconds() <= max_delta_seconds:
                return s
            return None
    return None


def pair_trades(signals: list[SignalEvent], opens: list[TradeOpen], closes: list[TradeClose]) -> list[Trade]:
    signals_sorted = sorted(signals, key=lambda x: x.ts)
    opens_sorted = sorted(opens, key=lambda x: x.ts)
    closes_sorted = sorted(closes, key=lambda x: x.ts)

    trades: list[Trade] = []

    i = 0
    j = 0
    while i < len(opens_sorted) and j < len(closes_sorted):
        o = opens_sorted[i]
        c = closes_sorted[j]

        # Skip closes that occur before the next open (shouldn't happen, but be robust)
        if c.ts < o.ts:
            j += 1
            continue

        s = _nearest_prior_signal(signals_sorted, o.ts)

        trades.append(
            Trade(
                open_ts=o.ts,
                close_ts=c.ts,
                side=o.side,
                volume=o.volume,
                open_price=o.price,
                sl=o.sl,
                tp=o.tp,
                profit=c.profit,
                outcome=c.outcome,
                reason=c.reason,
                duration_min=(c.ts - o.ts).total_seconds() / 60.0,
                strength=(int(abs(s.strength)) if s else None),
                confluence_pct=(s.confluence_pct if s else None),
                entry=(s.entry if s else None),
            )
        )
        i += 1
        j += 1

    return trades


@dataclass(frozen=True)
class EquityPoint:
    close_ts: datetime
    balance_before: float
    profit: float
    balance_after: float
    peak: float
    dd_abs: float
    dd_pct: float


def compute_equity(trades: list[Trade], initial_deposit: float) -> list[EquityPoint]:
    balance = initial_deposit
    peak = initial_deposit
    curve: list[EquityPoint] = []

    for t in sorted(trades, key=lambda x: x.close_ts):
        balance_before = balance
        balance_after = balance_before + t.profit
        peak = max(peak, balance_after)
        dd_abs = peak - balance_after
        dd_pct = (dd_abs / peak * 100.0) if peak > 0 else 0.0
        curve.append(
            EquityPoint(
                close_ts=t.close_ts,
                balance_before=balance_before,
                profit=t.profit,
                balance_after=balance_after,
                peak=peak,
                dd_abs=dd_abs,
                dd_pct=dd_pct,
            )
        )
        balance = balance_after

    return curve


def _streaks(values: list[bool]) -> int:
    best = 0
    cur = 0
    for v in values:
        if v:
            cur += 1
            best = max(best, cur)
        else:
            cur = 0
    return best


def summarize(trades: list[Trade], equity: list[EquityPoint], initial_deposit: float) -> dict:
    profits = [t.profit for t in trades]
    wins = [p for p in profits if p > 0]
    losses = [p for p in profits if p < 0]

    gross_profit = sum(wins)
    gross_loss = -sum(losses)
    profit_factor = (gross_profit / gross_loss) if gross_loss > 0 else float("inf")

    win_rate = (len(wins) / len(profits) * 100.0) if profits else 0.0
    expectancy = mean(profits) if profits else 0.0

    last_balance = equity[-1].balance_after if equity else initial_deposit
    net = last_balance - initial_deposit

    max_dd_abs = max((p.dd_abs for p in equity), default=0.0)
    max_dd_pct = max((p.dd_pct for p in equity), default=0.0)

    max_consec_losses = _streaks([p < 0 for p in profits])
    max_consec_wins = _streaks([p > 0 for p in profits])
    max_consec_stoploss = _streaks([("Stop Loss" in t.reason and t.profit < 0) for t in trades])

    avg_win = mean(wins) if wins else 0.0
    avg_loss = mean(losses) if losses else 0.0
    std_profit = pstdev(profits) if len(profits) >= 2 else 0.0

    return {
        "trades": len(trades),
        "wins": len(wins),
        "losses": len(losses),
        "win_rate_pct": win_rate,
        "net": net,
        "gross_profit": gross_profit,
        "gross_loss": gross_loss,
        "profit_factor": profit_factor,
        "expectancy": expectancy,
        "avg_win": avg_win,
        "avg_loss": avg_loss,
        "std_profit": std_profit,
        "max_dd_abs": max_dd_abs,
        "max_dd_pct": max_dd_pct,
        "max_consec_losses": max_consec_losses,
        "max_consec_wins": max_consec_wins,
        "max_consec_stoploss": max_consec_stoploss,
        "final_balance": last_balance,
    }


def _md_table(headers: list[str], rows: list[list[str]]) -> str:
    out = []
    out.append("| " + " | ".join(headers) + " |")
    out.append("| " + " | ".join(["---"] * len(headers)) + " |")
    for r in rows:
        out.append("| " + " | ".join(r) + " |")
    return "\n".join(out)


def _group_sum(trades: list[Trade], key_fn):
    agg: dict = {}
    for t in trades:
        k = key_fn(t)
        if k not in agg:
            agg[k] = {"trades": 0, "pnl": 0.0, "wins": 0, "losses": 0}
        agg[k]["trades"] += 1
        agg[k]["pnl"] += t.profit
        if t.profit > 0:
            agg[k]["wins"] += 1
        elif t.profit < 0:
            agg[k]["losses"] += 1
    return agg


def render_report(
    *,
    log_path: Path,
    initial_deposit: float | None,
    trades: list[Trade],
    equity: list[EquityPoint],
) -> str:
    lines: list[str] = []
    lines.append("# Relatório Financeiro — Análise Avançada do Log (MT5)\n")
    lines.append(f"- Log: `{log_path.name}`")
    lines.append(f"- Trades extraídos (open/close via linhas do EA): **{len(trades)}**")
    if initial_deposit is not None:
        lines.append(f"- Depósito inicial (log): **{initial_deposit:.2f}**\n")
    else:
        lines.append("- Depósito inicial (log): (não encontrado)\n")

    if not trades:
        lines.append("## Resultado\n")
        lines.append("Nenhum trade foi extraído com os padrões atuais (TRADE / TRADE CLOSED).")
        return "\n".join(lines)

    init = float(initial_deposit or 0.0)
    s = summarize(trades, equity, init)

    lines.append("## Sumário\n")
    lines.append(
        "\n".join(
            [
                f"- Trades: **{s['trades']}** (WIN: {s['wins']} | LOSS: {s['losses']} | WinRate: {s['win_rate_pct']:.1f}%)",
                f"- Lucro líquido: **{s['net']:.2f}** | Saldo final (fechado): **{s['final_balance']:.2f}**",
                f"- Profit Factor: **{s['profit_factor']:.2f}**",
                f"- Expectancy (EV por trade): **{s['expectancy']:.3f}** | Desvio-padrão PnL: **{s['std_profit']:.3f}**",
                f"- Média WIN: **{s['avg_win']:.3f}** | Média LOSS: **{s['avg_loss']:.3f}**",
                f"- Max DD (fechado): **{s['max_dd_abs']:.2f}** (**{s['max_dd_pct']:.2f}%**)",
                f"- Máx sequência: perdas **{s['max_consec_losses']}**, ganhos **{s['max_consec_wins']}**, stop-loss com prejuízo **{s['max_consec_stoploss']}**",
            ]
        )
    )

    # Breakdown: by day (close date)
    by_day = _group_sum(trades, lambda t: t.close_ts.date().isoformat())
    day_rows = []
    for day, a in sorted(by_day.items(), key=lambda kv: kv[0]):
        wr = (a["wins"] / a["trades"] * 100.0) if a["trades"] else 0.0
        day_rows.append([
            day,
            str(a["trades"]),
            f"{a['pnl']:.2f}",
            f"{wr:.1f}%",
        ])

    lines.append("\n## Por Dia (fechamento)\n")
    lines.append(_md_table(["Dia", "Trades", "PnL", "WinRate"], day_rows))

    # Breakdown: by hour (open hour)
    by_hour = _group_sum(trades, lambda t: f"{t.open_ts.hour:02d}")
    hour_rows = []
    for hour, a in sorted(by_hour.items(), key=lambda kv: kv[0]):
        hour_rows.append([hour, str(a["trades"]), f"{a['pnl']:.2f}"])
    lines.append("\n## Por Hora (abertura)\n")
    lines.append(_md_table(["Hora", "Trades", "PnL"], hour_rows))

    # Breakdown: by strength (if available)
    with_strength = [t for t in trades if t.strength is not None]
    if with_strength:
        by_strength = _group_sum(with_strength, lambda t: str(t.strength))
        strength_rows = []
        for st, a in sorted(by_strength.items(), key=lambda kv: int(kv[0])):
            wr = (a["wins"] / a["trades"] * 100.0) if a["trades"] else 0.0
            strength_rows.append([st, str(a["trades"]), f"{a['pnl']:.2f}", f"{wr:.1f}%"])
        lines.append("\n## Por Força (F)\n")
        lines.append(_md_table(["Força", "Trades", "PnL", "WinRate"], strength_rows))
    else:
        lines.append("\n## Por Força (F)\n")
        lines.append("Não foi possível inferir a força para os trades (linhas 'Sinal detectado' não foram associadas).")

    # Reasons
    reason_counts: dict[str, int] = {}
    for t in trades:
        reason_counts[t.reason] = reason_counts.get(t.reason, 0) + 1
    top_reasons = sorted(reason_counts.items(), key=lambda kv: (-kv[1], kv[0]))[:12]
    lines.append("\n## Razões de Saída (Top)\n")
    lines.append(_md_table(["Razão", "Contagem"], [[r, str(c)] for r, c in top_reasons]))

    return "\n".join(lines) + "\n"


def write_trades_csv(trades: list[Trade], csv_path: Path) -> None:
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    with csv_path.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(
            [
                "open_ts",
                "close_ts",
                "side",
                "volume",
                "open_price",
                "sl",
                "tp",
                "profit",
                "outcome",
                "reason",
                "duration_min",
                "strength",
                "confluence_pct",
                "entry",
            ]
        )
        for t in trades:
            w.writerow(
                [
                    t.open_ts.isoformat(sep=" "),
                    t.close_ts.isoformat(sep=" "),
                    t.side,
                    f"{t.volume:.8f}",
                    f"{t.open_price:.8f}",
                    f"{t.sl:.8f}",
                    f"{t.tp:.8f}",
                    f"{t.profit:.8f}",
                    t.outcome,
                    t.reason,
                    f"{t.duration_min:.3f}",
                    "" if t.strength is None else str(t.strength),
                    "" if t.confluence_pct is None else f"{t.confluence_pct:.1f}",
                    "" if t.entry is None else str(t.entry),
                ]
            )


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("log", nargs="?", default=str(DEFAULT_LOG_PATH), help="Path to MT5 .log")
    ap.add_argument("--report", default=str(DEFAULT_REPORT_PATH), help="Markdown output path")
    ap.add_argument("--csv", default=str(DEFAULT_TRADES_CSV), help="CSV output path")
    args = ap.parse_args()

    log_path = Path(args.log)
    if not log_path.exists():
        raise SystemExit(f"Log não encontrado: {log_path}")

    lines = _parse_lines(log_path)
    initial_deposit = parse_initial_deposit(lines)
    signals, opens, closes = parse_events(lines)
    trades = pair_trades(signals, opens, closes)

    init = float(initial_deposit or 0.0)
    equity = compute_equity(trades, init)

    report = render_report(log_path=log_path, initial_deposit=initial_deposit, trades=trades, equity=equity)
    report_path = Path(args.report)
    report_path.write_text(report, encoding="utf-8")

    write_trades_csv(trades, Path(args.csv))

    print(report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
