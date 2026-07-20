"""
現在の assets.db を新CSVフォーマットにエクスポートし、DB内の重複行を除去するワンショットスクリプト。
生成されたCSVが今後の正規データソースとなる。

Usage:
    uv run python scripts/export_csv.py
"""

import pathlib
import sqlite3

import pandas as pd

DB_PATH = pathlib.Path(__file__).parent.parent.parent / "assets.db"
EXPORTS = pathlib.Path(__file__).parent.parent.parent / "exports"

TX_COLS = [
    "account_type", "ticker_code", "ticker_name", "trade_date",
    "trade_type", "profit_type", "quantity",
    "sale_amount", "cost_amount", "profit_loss", "tax", "category",
    "year", "month", "acq_date",
]

HOLDING_COLS = [
    "ticker_code", "ticker_name", "account_type", "category",
    "quantity", "avg_cost", "total_cost", "yf_ticker",
]


def export_transactions(conn: sqlite3.Connection) -> int:
    df = pd.read_sql_query(
        f"SELECT {', '.join(TX_COLS)} FROM transactions ORDER BY trade_date, account_type, ticker_name",
        conn,
    )
    before = len(df)
    df = df.drop_duplicates(
        subset=["account_type", "ticker_code", "ticker_name", "trade_date", "profit_type", "sale_amount", "cost_amount", "acq_date"]
    )
    removed = before - len(df)
    df.to_csv(EXPORTS / "transactions.csv", index=False, encoding="utf-8-sig")
    print(f"transactions.csv: {len(df)} 件エクスポート（重複 {removed} 件除去）")
    return len(df)


def export_holdings(conn: sqlite3.Connection) -> int:
    df = pd.read_sql_query(
        f"SELECT {', '.join(HOLDING_COLS)} FROM holdings ORDER BY category, account_type, ticker_name",
        conn,
    )
    df.to_csv(EXPORTS / "holdings.csv", index=False, encoding="utf-8-sig")
    print(f"holdings.csv: {len(df)} 件エクスポート")
    return len(df)


def clean_db_duplicates(conn: sqlite3.Connection) -> int:
    """transactionsの重複行を削除し、idが最小の行を残す。"""
    cur = conn.execute("""
        DELETE FROM transactions
        WHERE id NOT IN (
            SELECT MIN(id)
            FROM transactions
            GROUP BY account_type, ticker_code, ticker_name, trade_date, profit_type, sale_amount, cost_amount, acq_date
        )
    """)
    removed = cur.rowcount
    print(f"DB重複削除: {removed} 件削除")
    return removed


def main() -> None:
    EXPORTS.mkdir(exist_ok=True)

    conn = sqlite3.connect(DB_PATH)
    try:
        export_transactions(conn)
        export_holdings(conn)
        clean_db_duplicates(conn)
        conn.commit()
        print("完了。exports/ 以下のCSVが正規データソースです。")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
