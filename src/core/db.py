import contextlib
import csv as _csv
import math
import pathlib
import re as _re
import sqlite3
from collections import defaultdict as _defaultdict
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
    month        INTEGER NOT NULL DEFAULT 1,
    acq_date     TEXT NOT NULL DEFAULT ''
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
    ON transactions(account_type, ticker_code, ticker_name, trade_date, profit_type, sale_amount, cost_amount, acq_date);

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
        # Migration: add acq_date column if it doesn't exist yet
        cols = {row[1] for row in conn.execute("PRAGMA table_info(transactions)")}
        if "acq_date" not in cols:
            conn.execute("ALTER TABLE transactions ADD COLUMN acq_date TEXT NOT NULL DEFAULT ''")
        # Migration: rebuild UNIQUE INDEX to include acq_date
        indexes = {row[1] for row in conn.execute("PRAGMA index_list(transactions)")}
        if "uq_transaction" in indexes:
            idx_info = conn.execute("SELECT sql FROM sqlite_master WHERE name='uq_transaction'").fetchone()
            if idx_info and "acq_date" not in idx_info[0]:
                conn.execute("DROP INDEX uq_transaction")
                conn.execute(
                    "CREATE UNIQUE INDEX uq_transaction ON transactions"
                    "(account_type, ticker_code, ticker_name, trade_date, profit_type, sale_amount, cost_amount, acq_date)"
                )


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
                    quantity, sale_amount, cost_amount, profit_loss, tax, category, year, month, acq_date)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
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
                    _s(r.get("acq_date")),
                ),
            )
            if cur.lastrowid and cur.rowcount:
                inserted += 1
            else:
                skipped += 1
    return {"inserted": inserted, "skipped": skipped}


_TRADE_TYPE_MAP = {
    "現物売": ("売却", "日本株"),
    "株式現物売": ("売却", "日本株"),
    "株式配当金": ("配当", "日本株"),
    "投信分配金": ("配当", "投資信託"),
    "国内投信解約": ("売却", "投資信託"),
    "外国株式売": ("売却", "外国株"),
    "外国株式配当金": ("配当", "外国株"),
    "外国投信分配金": ("配当", "外国投信"),
    "資本剰余金配当/みなし譲渡": ("配当", "日本株"),
}


_TAX_LABELS = {"譲渡益税徴収額", "配当所得税徴収額", "譲渡益税還付金", "配当所得税還付金"}
_REFUND_LABELS = {"譲渡益税還付金", "配当所得税還付金"}


def _parse_date_tokutei(s: str) -> str:
    if not s or s.strip() in ("", "--", "----/--/--"):
        return ""
    s = s.strip()
    if "~" in s:
        s = s.split("~")[0].strip()
    m = _re.match(r"^(\d{4})/(\d{1,2})/(\d{1,2})$", s)
    if m:
        return f"{m.group(1)}-{int(m.group(2)):02d}-{int(m.group(3)):02d}"
    return ""


def _parse_int_tokutei(s: str) -> int:
    if not s or s.strip() in ("", "--"):
        return 0
    try:
        return int(s.replace(",", "").strip())
    except ValueError:
        return 0


def _parse_lots_from_text(text: str, conn: sqlite3.Connection) -> list[dict]:
    """CSVテキストから取引ロットのリストを返す。

    特定口座損益CSVの列構成（0始まり）:
      0: 銘柄コード, 1: 銘柄名, 2: (空), 3: (空), 4: 取引種別,
      5: 約定日, 6: 受渡日, 7: 数量, 8: (空), 9: 売却/受取金額,
      10: 取得費, 11: (空), 12: 損益, 13: 取得日, 14: (空)
    """
    lots = []
    current_year = None
    for row in _csv.reader(text.splitlines()):
        if len(row) < 13:
            row = row + [""] * (13 - len(row))
        # Pad to at least 15 for safety
        while len(row) < 15:
            row.append("")
        c0, c1 = row[0].strip(), row[1].strip()
        c4 = row[4].strip()   # 取引種別
        c5 = row[5].strip()   # 約定日
        c6 = row[6].strip()   # 受渡日
        c7 = row[7].strip()   # 数量
        c9 = row[9].strip()   # 売却/受取金額
        c10 = row[10].strip() # 取得費
        c12 = row[12].strip() # 損益
        c13 = row[13].strip() # 取得日

        # Year header row: c0 is 4-digit year, rest empty
        m = _re.match(r"^(\d{4})$", c0)
        if m and not c4:
            current_year = int(m.group(1))
            continue
        # Skip total rows
        if _re.match(r"^.+total$", c0, _re.IGNORECASE):
            continue
        # Skip tax/refund rows
        if c0 in _TAX_LABELS or c1 in _TAX_LABELS:
            continue
        # Skip header row
        if c1 == "銘柄":
            continue
        # Skip rows without required fields
        if current_year is None or not c1 or not c4 or not c12:
            continue
        if c4 not in _TRADE_TYPE_MAP:
            continue

        profit_type, default_cat = _TRADE_TYPE_MAP[c4]
        r = conn.execute(
            "SELECT category FROM transactions WHERE account_type='特定口座' AND ticker_name=? "
            "GROUP BY category ORDER BY COUNT(*) DESC LIMIT 1", (c1,)
        ).fetchone()
        category = r[0] if r else default_cat

        try:
            pl = int(c12.replace(",", ""))
        except ValueError:
            continue

        trade_date = _parse_date_tokutei(c5) or _parse_date_tokutei(c6)
        if not trade_date:
            continue

        qty = c7.strip()
        if qty in ("", "--", "----"):
            qty = ""

        lots.append({
            "ticker_name": c1,
            "trade_type": c4,
            "profit_type": profit_type,
            "category": category,
            "trade_date": trade_date,
            "settle_date": _parse_date_tokutei(c6),
            "qty": qty,
            "sale": _parse_int_tokutei(c9),
            "cost": _parse_int_tokutei(c10),
            "pl": pl,
            "acq_date": _parse_date_tokutei(c13),
            "year": int(trade_date[:4]),
            "month": int(trade_date[5:7]),
        })
    return lots


def import_tokutei_csv_text(text: str) -> dict:
    """特定口座損益CSVのテキストをDBに同期する。
    戻り値: {"inserted": N, "updated": N, "matched_existing": N, "total_lots": N}
    """
    with get_db() as conn:
        lots = _parse_lots_from_text(text, conn)
        csv_by_key: dict[tuple, list[dict]] = _defaultdict(list)
        for lot in lots:
            key = (lot["ticker_name"], lot["trade_date"], lot["sale"], lot["cost"])
            csv_by_key[key].append(lot)

        updated = 0
        inserted = 0
        matched_existing = 0

        for key, csv_lots in csv_by_key.items():
            ticker, trade_date, sale, cost = key
            db_rows = conn.execute(
                """SELECT id, acq_date FROM transactions
                   WHERE account_type='特定口座' AND ticker_name=? AND trade_date=?
                     AND sale_amount=? AND cost_amount=?""",
                (ticker, trade_date, sale, cost),
            ).fetchall()
            db_filled = [r for r in db_rows if r[1]]
            db_empty  = [r for r in db_rows if not r[1]]

            filled_acq = {r[1] for r in db_filled}
            remaining = [lot for lot in csv_lots if lot["acq_date"] not in filled_acq]
            matched_existing += len(csv_lots) - len(remaining)

            n_update = min(len(db_empty), len(remaining))
            for i in range(n_update):
                lot = remaining[i]
                conn.execute(
                    "UPDATE transactions SET acq_date=?, quantity=?, trade_type=?, "
                    "profit_type=?, category=? WHERE id=?",
                    (lot["acq_date"], lot["qty"], lot["trade_type"], lot["profit_type"],
                     lot["category"], db_empty[i][0]),
                )
                updated += 1

            for lot in remaining[n_update:]:
                cur = conn.execute(
                    """INSERT OR IGNORE INTO transactions
                       (account_type, ticker_code, ticker_name, trade_date, trade_type, profit_type,
                        quantity, sale_amount, cost_amount, profit_loss, tax, category, year, month, acq_date)
                       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                    ("特定口座", "", lot["ticker_name"], lot["trade_date"], lot["trade_type"],
                     lot["profit_type"], lot["qty"], lot["sale"], lot["cost"], lot["pl"], 0,
                     lot["category"], lot["year"], lot["month"], lot["acq_date"]),
                )
                if cur.rowcount:
                    inserted += 1

    return {"inserted": inserted, "updated": updated, "matched_existing": matched_existing,
            "total_lots": len(lots)}


_TAX_LABELS_SALE = {"譲渡益税徴収額"}
_TAX_LABELS_DIV  = {"配当所得税徴収額"}
_TAX_LABELS_SKIP = {"譲渡益税還付金", "配当所得税還付金"}
_SELL_TRADE_TYPES = {"現物売", "株式現物売", "国内投信解約", "外国株式売"}
_DIV_TRADE_TYPES  = {"株式配当金", "投信分配金", "外国株式配当金", "外国投信分配金",
                      "資本剰余金配当/みなし譲渡"}


def sync_tax_from_text(text: str) -> dict:
    """CSVテキストから税額を解析し、既存トランザクションの tax カラムを更新する。

    列構成は _parse_lots_from_text と同じ:
      0: 銘柄コード, 1: 銘柄名, 4: 取引種別, 5: 約定日, 6: 受渡日,
      9: 売却/受取金額, 10: 取得費, 12: 損益, 13: 取得日
    税行:
      0 or 1: 税ラベル, 6: 受渡日, 11: 所得税, 12: 住民税

    戻り値: {"updated": N, "unmatched": N}
    """
    # pending: 直近の取引行グループ（同一受渡日）
    pending: list[dict] = []
    lots_with_tax: list[dict] = []

    def flush() -> None:
        for t in pending:
            lots_with_tax.append(t)
        pending.clear()

    current_year = None

    for row in _csv.reader(text.splitlines()):
        while len(row) < 15:
            row.append("")
        c0, c1 = row[0].strip(), row[1].strip()

        # 年ヘッダー行
        m = _re.match(r"^(\d{4})$", c0)
        if m and not row[4].strip():
            flush()
            current_year = int(m.group(1))
            continue

        # total行
        if _re.match(r"^.+total$", c0, _re.IGNORECASE):
            flush()
            continue

        # 税/還付ラベル行を判定
        tax_label = c0 if c0 in _TAX_LABELS else (c1 if c1 in _TAX_LABELS else None)

        if tax_label:
            if tax_label in _TAX_LABELS_SKIP:
                continue
            # 税行の受渡日は c6 または c5 に入るCSVレイアウトの揺れに対応する
            settle = _parse_date_tokutei(row[6].strip()) or _parse_date_tokutei(row[5].strip())
            natl   = _parse_int_tokutei(row[11].strip())
            local  = _parse_int_tokutei(row[12].strip())
            tax_amt = natl + local
            if tax_amt == 0:
                continue

            if tax_label in _TAX_LABELS_SALE:
                targets = [t for t in pending if t["settle"] == settle
                           and t["trade_type"] in _SELL_TRADE_TYPES]
            else:
                targets = [t for t in pending if t["settle"] == settle
                           and t["trade_type"] in _DIV_TRADE_TYPES]

            if not targets:
                continue

            # 損益の絶対値で按分
            total_w = sum(abs(t["pl"]) for t in targets) or len(targets)
            allocated = 0
            for i, t in enumerate(targets):
                if i == len(targets) - 1:
                    share = tax_amt - allocated
                else:
                    w = abs(t["pl"]) if total_w > 0 else 1
                    share = int(tax_amt * w / total_w)
                    allocated += share
                t["tax"] += share
            continue

        # ヘッダー行・空行・年未確定行をスキップ
        if c1 == "銘柄" or not c1:
            continue
        if current_year is None:
            continue

        c4  = row[4].strip()   # 取引種別
        c5  = row[5].strip()   # 約定日
        c6  = row[6].strip()   # 受渡日
        c9  = row[9].strip()   # 売却/受取金額
        c10 = row[10].strip()  # 取得費
        c12 = row[12].strip()  # 損益
        c13 = row[13].strip()  # 取得日

        if not c4 or not c12:
            continue
        if c4 not in _TRADE_TYPE_MAP:
            continue

        try:
            pl = int(c12.replace(",", ""))
        except ValueError:
            continue

        trade_date = _parse_date_tokutei(c5) or _parse_date_tokutei(c6)
        settle = _parse_date_tokutei(c6)
        if not trade_date:
            continue

        # 受渡日が変わったらバッファをフラッシュ
        if pending and pending[-1]["settle"] != settle:
            flush()

        pending.append({
            "ticker": c1,
            "trade_date": trade_date,
            "settle": settle,
            "sale": _parse_int_tokutei(c9),
            "cost": _parse_int_tokutei(c10),
            "acq_date": _parse_date_tokutei(c13),
            "pl": pl,
            "trade_type": c4,
            "tax": 0,
        })

    flush()

    with_tax = [t for t in lots_with_tax if t["tax"] != 0]
    updated = 0
    unmatched = 0

    with get_db() as conn:
        for lot in with_tax:
            # まず acq_date で厳密マッチ
            rows = conn.execute(
                """SELECT id FROM transactions
                   WHERE account_type='特定口座' AND ticker_name=? AND trade_date=?
                     AND sale_amount=? AND cost_amount=? AND acq_date=?""",
                (lot["ticker"], lot["trade_date"], lot["sale"], lot["cost"], lot["acq_date"]),
            ).fetchall()
            # フォールバック: profit_loss で照合
            if not rows:
                rows = conn.execute(
                    """SELECT id FROM transactions
                       WHERE account_type='特定口座' AND ticker_name=? AND trade_date=?
                         AND sale_amount=? AND cost_amount=? AND profit_loss=?""",
                    (lot["ticker"], lot["trade_date"], lot["sale"], lot["cost"], lot["pl"]),
                ).fetchall()
            if not rows:
                unmatched += 1
                continue
            conn.execute(
                "UPDATE transactions SET tax=? WHERE id=?",
                (lot["tax"], rows[0][0]),
            )
            updated += 1

    return {"updated": updated, "unmatched": unmatched}


def sync_refund_from_text(text: str) -> dict:
    """CSVテキストから税金還付行を解析し、category='税金還付' レコードを再投入する。
    既存の category='税金還付' をすべて削除してから再INSERT（冪等）。
    戻り値: {"deleted": N, "inserted": N}
    """
    refunds = []
    for row in _csv.reader(text.splitlines()):
        if len(row) < 13:
            row = row + [""] * (13 - len(row))
        c0, c1 = row[0].strip(), row[1].strip()

        label = None
        if c0 in _REFUND_LABELS:
            label = c0
        elif c1 in _REFUND_LABELS:
            label = c1
        if not label:
            continue

        # 受渡日: col5 または col6（CSVレイアウトにより異なる）
        settle = _parse_date_tokutei(row[5].strip() if len(row) > 5 else "")
        if not settle:
            settle = _parse_date_tokutei(row[6].strip() if len(row) > 6 else "")
        if not settle:
            continue

        natl  = _parse_int_tokutei(row[11].strip() if len(row) > 11 else "")
        local = _parse_int_tokutei(row[12].strip() if len(row) > 12 else "")
        amt = natl + local
        if amt == 0:
            continue

        refunds.append({
            "trade_date": settle,
            "trade_type": label,
            "profit_type": label,
            "profit_loss": amt,
            "year": int(settle[:4]),
            "month": int(settle[5:7]),
        })

    with get_db() as conn:
        cur = conn.execute("DELETE FROM transactions WHERE category='税金還付'")
        deleted = cur.rowcount
        inserted = 0
        for r in refunds:
            cur = conn.execute(
                """INSERT OR IGNORE INTO transactions
                   (account_type, ticker_code, ticker_name, trade_date, trade_type, profit_type,
                    quantity, sale_amount, cost_amount, profit_loss, tax, category, year, month, acq_date)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                ("特定口座", "", r["trade_type"], r["trade_date"],
                 r["trade_type"], r["profit_type"],
                 "", 0, 0, r["profit_loss"], 0,
                 "税金還付", r["year"], r["month"], ""),
            )
            if cur.rowcount:
                inserted += 1

    return {"deleted": deleted, "inserted": inserted}


_MANUAL_TICKER_MAP: dict[str, str] = {}


def fill_ticker_codes_from_text(text: str) -> dict:
    """CSVテキストの銘柄コード/銘柄名マッピングと MANUAL_MAP を使って
    transactions.ticker_code の空欄を埋める。
    戻り値: {"updated": N, "unmapped": [銘柄名, ...]}
    """
    from collections import Counter
    mapping: dict[str, Counter[str]] = {}
    for row in _csv.reader(text.splitlines()):
        if len(row) < 2:
            continue
        c0, c1 = row[0].strip(), row[1].strip()
        if not c0 or not c1:
            continue
        if c0 in _TAX_LABELS or c1 in _TAX_LABELS:
            continue
        if _re.match(r"^.+total$", c0) or c1 == "銘柄":
            continue
        if _re.match(r"^\d{4}$", c0) or _re.match(r"^[A-Z]+$", c0):
            mapping.setdefault(c1, Counter())[c0] += 1

    csv_map = {name: c.most_common(1)[0][0] for name, c in mapping.items()}
    final_map = {**_MANUAL_TICKER_MAP, **csv_map}

    updated = 0
    unmapped: list[str] = []
    with get_db() as conn:
        for row in conn.execute(
            "SELECT DISTINCT ticker_name FROM transactions WHERE ticker_code = ''"
        ).fetchall():
            name = row[0]
            code = final_map.get(name)
            if code:
                cur = conn.execute(
                    "UPDATE transactions SET ticker_code=? WHERE ticker_name=? AND ticker_code=''",
                    (code, name),
                )
                updated += cur.rowcount
            else:
                unmapped.append(name)

    return {"updated": updated, "unmapped": unmapped}


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
