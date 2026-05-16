import contextlib
import math
import pathlib
import sqlite3
from typing import Generator

import pandas as pd

def _s(v, default: str = "") -> str:
    """NaN / None を空文字に変換。"""
    if v is None:
        return default
    if isinstance(v, float) and math.isnan(v):
        return default
    return str(v)


_TX_REQUIRED_COLS = {
    "account_type", "ticker_code", "ticker_name", "trade_date",
    "trade_type", "profit_type", "quantity",
    "sale_amount", "cost_amount", "profit_loss", "tax", "category",
}
_HOLDING_REQUIRED_COLS = {
    "ticker_code", "ticker_name", "account_type", "category",
    "quantity", "avg_cost", "total_cost", "yf_ticker",
}

DB_PATH = pathlib.Path(__file__).parent.parent.parent / "assets.db"

_SCHEMA = """
CREATE TABLE IF NOT EXISTS transactions (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    account_type TEXT NOT NULL,
    ticker_code  TEXT NOT NULL DEFAULT '',
    ticker_name  TEXT NOT NULL,
    trade_date   TEXT NOT NULL,
    trade_type   TEXT NOT NULL,
    profit_type  TEXT NOT NULL,
    quantity     TEXT DEFAULT '',
    sale_amount  INTEGER DEFAULT 0,
    cost_amount  INTEGER DEFAULT 0,
    profit_loss  INTEGER DEFAULT 0,
    tax          INTEGER DEFAULT 0,
    category     TEXT NOT NULL,
    year         INTEGER NOT NULL,
    month        INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS holdings (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    ticker_code  TEXT DEFAULT '',
    ticker_name  TEXT NOT NULL,
    account_type TEXT NOT NULL DEFAULT '特定口座',
    category     TEXT NOT NULL,
    quantity     REAL DEFAULT 0,
    avg_cost     REAL DEFAULT 0,
    total_cost   REAL DEFAULT 0,
    yf_ticker    TEXT DEFAULT '',
    last_price   REAL,
    last_updated TEXT DEFAULT '',
    UNIQUE(ticker_name, account_type)
);

CREATE TABLE IF NOT EXISTS portfolio_snapshots (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    snapshot_date       TEXT NOT NULL UNIQUE,
    total_assets        REAL DEFAULT 0,
    realized_cumulative REAL DEFAULT 0,
    realized_annual     REAL DEFAULT 0,
    unrealized_gains    REAL DEFAULT 0
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_transaction
    ON transactions(account_type, ticker_code, ticker_name, trade_date, profit_type, sale_amount, cost_amount);

CREATE INDEX IF NOT EXISTS idx_tx_year     ON transactions(year);
CREATE INDEX IF NOT EXISTS idx_tx_category ON transactions(category);
CREATE INDEX IF NOT EXISTS idx_tx_ptype    ON transactions(profit_type);
CREATE INDEX IF NOT EXISTS idx_tx_account  ON transactions(account_type);
"""


@contextlib.contextmanager
def get_db() -> Generator[sqlite3.Connection, None, None]:
    conn = sqlite3.connect(
        DB_PATH,
        check_same_thread=False,
        detect_types=sqlite3.PARSE_DECLTYPES,
    )
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def init_db() -> None:
    with get_db() as conn:
        conn.executescript(_SCHEMA)


def query_df(sql: str, params: tuple = ()) -> pd.DataFrame:
    with get_db() as conn:
        return pd.read_sql_query(sql, conn, params=params)


def execute(sql: str, params: tuple = ()) -> None:
    with get_db() as conn:
        conn.execute(sql, params)


def executemany(sql: str, rows: list) -> None:
    with get_db() as conn:
        conn.executemany(sql, rows)


def has_data() -> bool:
    with get_db() as conn:
        row = conn.execute("SELECT COUNT(*) FROM transactions").fetchone()
        return row[0] > 0


def import_transactions_csv(df: pd.DataFrame) -> dict:
    """差分インポート。重複キー一致行はスキップ。{'inserted': N, 'skipped': M} を返す。"""
    missing = _TX_REQUIRED_COLS - set(df.columns)
    if missing:
        raise ValueError(f"CSVに必須カラムがありません: {missing}")

    df = df.copy()
    df["trade_date"] = pd.to_datetime(df["trade_date"], errors="coerce").dt.strftime("%Y-%m-%d")
    if df["trade_date"].isna().any():
        raise ValueError("trade_date に変換できない値があります（形式: YYYY-MM-DD）")
    df["year"] = pd.to_datetime(df["trade_date"]).dt.year
    df["month"] = pd.to_datetime(df["trade_date"]).dt.month

    inserted = 0
    skipped = 0
    with get_db() as conn:
        for _, r in df.iterrows():
            cur = conn.execute(
                """INSERT OR IGNORE INTO transactions
                   (account_type, ticker_code, ticker_name, trade_date, trade_type, profit_type,
                    quantity, sale_amount, cost_amount, profit_loss, tax, category, year, month)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    _s(r.get("account_type")),
                    _s(r.get("ticker_code")),
                    _s(r.get("ticker_name")),
                    str(r["trade_date"]),
                    _s(r.get("trade_type")),
                    _s(r.get("profit_type")),
                    _s(r.get("quantity")),
                    int(r.get("sale_amount") or 0),
                    int(r.get("cost_amount") or 0),
                    int(r.get("profit_loss") or 0),
                    int(r.get("tax") or 0),
                    _s(r.get("category")),
                    int(r["year"]),
                    int(r["month"]),
                ),
            )
            if cur.lastrowid and cur.rowcount:
                inserted += 1
            else:
                skipped += 1
    return {"inserted": inserted, "skipped": skipped}


def import_holdings_csv(df: pd.DataFrame) -> dict:
    """保有銘柄をUPSERT（ticker_name + account_type が一致すれば値を更新）。"""
    missing = _HOLDING_REQUIRED_COLS - set(df.columns)
    if missing:
        raise ValueError(f"CSVに必須カラムがありません: {missing}")

    with get_db() as conn:
        conn.executemany(
            """INSERT INTO holdings
               (ticker_code, ticker_name, account_type, category,
                quantity, avg_cost, total_cost, yf_ticker)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)
               ON CONFLICT(ticker_name, account_type) DO UPDATE SET
                   ticker_code = excluded.ticker_code,
                   category    = excluded.category,
                   quantity    = excluded.quantity,
                   avg_cost    = excluded.avg_cost,
                   total_cost  = excluded.total_cost,
                   yf_ticker   = excluded.yf_ticker""",
            [
                (
                    _s(r.get("ticker_code")),
                    _s(r.get("ticker_name")),
                    _s(r.get("account_type"), "特定口座"),
                    _s(r.get("category")),
                    float(r.get("quantity") or 0),
                    float(r.get("avg_cost") or 0),
                    float(r.get("total_cost") or 0),
                    _s(r.get("yf_ticker")),
                )
                for _, r in df.iterrows()
                if _s(r.get("ticker_name")).strip()
            ],
        )
    return {"upserted": len(df)}
