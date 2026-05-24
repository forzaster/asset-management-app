"""Apple版アプリ向けのZIP形式エクスポート。

assets.db の全テーブルをCSVに出力し、meta.jsonと共に1つのZIPにまとめる。
Apple版は ImportService 経由でこのZIPを取り込む。
"""

from __future__ import annotations

import json
import pathlib
import sqlite3
import zipfile
from datetime import datetime, timezone

import pandas as pd

TX_COLS = [
    "account_type", "ticker_code", "ticker_name", "trade_date",
    "trade_type", "profit_type", "quantity",
    "sale_amount", "cost_amount", "profit_loss", "tax", "category",
    "year", "month", "acq_date",
]
HOLDING_COLS = [
    "ticker_code", "ticker_name", "account_type", "category",
    "quantity", "avg_cost", "total_cost", "yf_ticker", "last_price", "last_updated",
]
SNAPSHOT_COLS = [
    "snapshot_date", "total_assets", "realized_cumulative",
    "realized_annual", "unrealized_gains",
]

SCHEMA_VERSION = 1


def _read_table(conn: sqlite3.Connection, table: str, cols: list[str]) -> pd.DataFrame:
    sql = f"SELECT {', '.join(cols)} FROM {table}"
    try:
        return pd.read_sql_query(sql, conn)
    except pd.errors.DatabaseError:
        return pd.DataFrame(columns=cols)


def export_apple_zip(
    db_path: pathlib.Path,
    out_dir: pathlib.Path,
) -> pathlib.Path:
    """ZIPファイルを生成して返す。

    出力先: {out_dir}/YYYYMMDD_HHMMSS_assets_export.zip
    """
    out_dir.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now(timezone.utc).astimezone()
    zip_name = timestamp.strftime("%Y%m%d_%H%M%S") + "_assets_export.zip"
    zip_path = out_dir / zip_name

    conn = sqlite3.connect(db_path)
    try:
        tx = _read_table(conn, "transactions", TX_COLS)
        hd = _read_table(conn, "holdings", HOLDING_COLS)
        sn = _read_table(conn, "portfolio_snapshots", SNAPSHOT_COLS)
    finally:
        conn.close()

    meta = {
        "schema_version": SCHEMA_VERSION,
        "exported_at": timestamp.isoformat(),
        "tables": {
            "transactions": len(tx),
            "holdings": len(hd),
            "snapshots": len(sn),
        },
    }

    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("meta.json", json.dumps(meta, ensure_ascii=False, indent=2))
        z.writestr("transactions.csv", tx.to_csv(index=False, encoding="utf-8-sig"))
        z.writestr("holdings.csv", hd.to_csv(index=False, encoding="utf-8-sig"))
        z.writestr("snapshots.csv", sn.to_csv(index=False, encoding="utf-8-sig"))

    return zip_path


def main() -> None:
    # 実行時のパス基準: python/src/scripts/export_apple_zip.py → python/
    python_root = pathlib.Path(__file__).parent.parent.parent
    db = python_root / "assets.db"
    out = python_root / "exports" / "apple"
    path = export_apple_zip(db, out)
    print(f"Apple版向けZIPを出力: {path}")


if __name__ == "__main__":
    main()
