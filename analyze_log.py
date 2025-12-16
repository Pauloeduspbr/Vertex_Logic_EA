
import re
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

import numpy as np
import pandas as pd


DEFAULT_LOG_PATH = Path(__file__).resolve().parent / "20251215.log"
DEFAULT_REPORT_PATH = Path(__file__).resolve().parent / "financial_analysis_report.md"


def read_log_lines(log_path: Path) -> list[str]:
    data = log_path.read_bytes()
    # MT5 tester logs are often UTF-16LE with BOM (common on Windows/Wine).
    if data.startswith(b"\xff\xfe") or data.startswith(b"\xfe\xff"):
        text = data.decode("utf-16", errors="ignore")
    else:
        try:
            text = data.decode("utf-8")
        except UnicodeDecodeError:
            text = data.decode("latin-1", errors="ignore")
    return text.splitlines()


@dataclass
class TradeClose:
    ts: datetime
    outcome: str  # WIN/LOSS
    profit: float
    reason: str


@dataclass
class TradeOpen:
    ts: datetime
    side: str  # BUY/SELL
    price: float
    volume: float
    sl: float
    tp: float


def _parse_mt5_ts(line: str) -> datetime | None:
    # Ex: "...\t2023.01.04 14:30:00   [14:30:00] ..."
    m = re.search(r"\t(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})\s+", line)
    if not m:
        return None
    return datetime.strptime(m.group(1), "%Y.%m.%d %H:%M:%S")


def parse_initial_deposit(lines: list[str]) -> float | None:
    m = None
    for line in lines:
        m = re.search(r"initial deposit\s+(\d+(?:\.\d+)?)", line, re.IGNORECASE)
        if m:
            return float(m.group(1))
    return None


def parse_trades(lines: list[str]) -> tuple[list[TradeOpen], list[TradeClose]]:
    open_pattern = re.compile(
        r"\t(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})\s+\[\d{2}:\d{2}:\d{2}\]\s+\[INFO\]\s+TRADE:\s+(BUY|SELL)\s+@\s+([0-9.]+)\s+\|\s+Vol:\s+([0-9.]+)\s+\|\s+SL:\s+([0-9.]+)\s+\|\s+TP:\s+([0-9.]+)"
    )
    close_pattern = re.compile(
        r"\t(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})\s+\[\d{2}:\d{2}:\d{2}\]\s+\[INFO\]\s+TRADE CLOSED:\s+(WIN|LOSS)\s+\|\s+Profit:\s+(-?[0-9.]+)\s+\|\s+Raz[aã]o:\s+(.*)$"
    )

    opens: list[TradeOpen] = []
    closes: list[TradeClose] = []

    for line in lines:
        mo = open_pattern.search(line)
        if mo:
            ts = datetime.strptime(mo.group(1), "%Y.%m.%d %H:%M:%S")
            opens.append(
                TradeOpen(
                    ts=ts,
                    side=mo.group(2),
                    price=float(mo.group(3)),
                    volume=float(mo.group(4)),
                    sl=float(mo.group(5)),
                    tp=float(mo.group(6)),
                )
            )
            continue

        mc = close_pattern.search(line)
        if mc:
            ts = datetime.strptime(mc.group(1), "%Y.%m.%d %H:%M:%S")
            closes.append(
                TradeClose(
                    ts=ts,
                    outcome=mc.group(2),
                    profit=float(mc.group(3)),
                    reason=mc.group(4).strip(),
                )
            )

    return opens, closes


def pair_trades(opens: list[TradeOpen], closes: list[TradeClose]) -> pd.DataFrame:
    # Este EA parece operar 1 posição por vez. Emparelhamos em ordem temporal.
    opens_sorted = sorted(opens, key=lambda x: x.ts)
    closes_sorted = sorted(closes, key=lambda x: x.ts)

    n = min(len(opens_sorted), len(closes_sorted))
    rows = []
    for i in range(n):
        o = opens_sorted[i]
        c = closes_sorted[i]
        rows.append(
            {
                "open_ts": o.ts,
                "close_ts": c.ts,
                "side": o.side,
                "volume": o.volume,
                "open_price": o.price,
                "sl": o.sl,
                "tp": o.tp,
                "profit": c.profit,
                "outcome": c.outcome,
                "reason": c.reason,
                "duration_min": (c.ts - o.ts).total_seconds() / 60.0,
            }
        )
    return pd.DataFrame(rows)


def compute_equity_curve(df: pd.DataFrame, initial_deposit: float) -> pd.DataFrame:
    df = df.sort_values("close_ts").reset_index(drop=True)
    df["balance_before"] = initial_deposit + df["profit"].shift(1).fillna(0).cumsum()
    df["balance_after"] = df["balance_before"] + df["profit"]
    df["dd_from_peak_pct"] = (
        (df["balance_after"].cummax() - df["balance_after"]) / df["balance_after"].cummax()
    ) * 100.0
    df["loss_pct_of_balance"] = np.where(
        df["profit"] < 0,
        (-df["profit"]) / df["balance_before"] * 100.0,
        0.0,
    )
    return df


def render_report(df: pd.DataFrame, initial_deposit: float | None, log_path: Path) -> str:
    report = []
    report.append("# Relatório Financeiro — Análise do Log do Strategy Tester\n")
    report.append(f"- Log: `{log_path.name}`\n")

    if initial_deposit is None:
        report.append("- Depósito inicial: (não encontrado no log)\n")
        initial_deposit = float(df["profit"].cumsum().iloc[0] * 0 + 0)  # 0, só para tipo
    else:
        report.append(f"- Depósito inicial (log): **{initial_deposit:.2f}**\n")

    if df.empty:
        report.append("\n## Resultado\n")
        report.append("Nenhum trade (open/close) foi extraído do log com os padrões atuais.\n")
        return "\n".join(report)

    net = df["profit"].sum()
    gross_profit = df.loc[df["profit"] > 0, "profit"].sum()
    gross_loss = -df.loc[df["profit"] < 0, "profit"].sum()
    profit_factor = (gross_profit / gross_loss) if gross_loss > 0 else np.inf
    win_rate = (df["profit"] > 0).mean() * 100.0
    avg_win = df.loc[df["profit"] > 0, "profit"].mean() if (df["profit"] > 0).any() else 0.0
    avg_loss = df.loc[df["profit"] < 0, "profit"].mean() if (df["profit"] < 0).any() else 0.0
    expectancy = df["profit"].mean()
    max_dd = df["dd_from_peak_pct"].max() if "dd_from_peak_pct" in df else np.nan

    report.append("\n## Sumário\n")
    report.append(f"- Trades analisados: **{len(df)}**\n")
    report.append(f"- Win rate: **{win_rate:.1f}%**\n")
    report.append(f"- Lucro líquido: **{net:.2f}**\n")
    report.append(f"- Profit Factor: **{profit_factor:.2f}**\n")
    report.append(f"- Expectancy (média por trade): **{expectancy:.2f}**\n")
    report.append(f"- Max Drawdown (por saldo fechado): **{max_dd:.2f}%**\n")
    report.append(f"- Média WIN: **{avg_win:.2f}** | Média LOSS: **{avg_loss:.2f}**\n")

    report.append("\n## Diagnóstico Quantitativo (por que a conta quebra)\n")
    worst_loss_pct = df["loss_pct_of_balance"].max()
    report.append(f"- Pior perda relativa (loss/balance_before): **{worst_loss_pct:.2f}%**\n")
    if worst_loss_pct >= 5:
        report.append(
            "- Isso indica **risco por trade alto** para o tamanho do depósito (o EA está operando praticamente como ~5–15% por trade em alguns pontos do log).\n"
        )

    side_counts = df["side"].value_counts(dropna=False).to_dict()
    report.append(f"- Direção: {side_counts}\n")

    reason_counts = df["reason"].value_counts().head(10).to_dict()
    report.append(f"- Principais razões de saída (top 10): {reason_counts}\n")

    report.append("\n## Observações Técnicas do Log\n")
    report.append(
        "- O log mostra múltiplos casos de `Drawdown diário ... excedeu limite`, o que combina com lote fixo elevado para depósito pequeno.\n"
    )
    report.append(
        "- Se `Inp_LotMode=LOT_FIXED`, o `Inp_RiskPercent` vira apenas 'informativo' a menos que o EA imponha um cap — isso é um dos motivos de quebra.\n"
    )

    return "\n".join(report)


def main() -> int:
    log_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_LOG_PATH
    report_path = Path(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_REPORT_PATH

    if not log_path.exists():
        raise SystemExit(f"Log não encontrado: {log_path}")

    lines = read_log_lines(log_path)
    initial_deposit = parse_initial_deposit(lines)
    opens, closes = parse_trades(lines)
    df = pair_trades(opens, closes)

    if initial_deposit is None:
        # fallback razoável: usar o primeiro reset de saldo (se existir) ou 0
        initial_deposit = 0.0
        m = re.search(r"Saldo inicial:\s+([0-9.]+)", "\n".join(lines[:2000]))
        if m:
            initial_deposit = float(m.group(1))

    if not df.empty:
        df = compute_equity_curve(df, float(initial_deposit))

    report = render_report(df, float(initial_deposit) if initial_deposit is not None else None, log_path)
    report_path.write_text(report, encoding="utf-8")
    print(report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
