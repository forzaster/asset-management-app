import json
import sqlite3
import zipfile
from pathlib import Path

from scripts.export_apple_zip import export_apple_zip


def _seed_db(db_path: Path) -> None:
    conn = sqlite3.connect(db_path)
    conn.executescript("""
        CREATE TABLE transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            account_type TEXT NOT NULL, ticker_code TEXT DEFAULT '',
            ticker_name TEXT NOT NULL, trade_date TEXT NOT NULL,
            trade_type TEXT NOT NULL, profit_type TEXT NOT NULL,
            quantity TEXT DEFAULT '', sale_amount INTEGER DEFAULT 0,
            cost_amount INTEGER DEFAULT 0, profit_loss INTEGER DEFAULT 0,
            tax INTEGER DEFAULT 0, category TEXT NOT NULL,
            year INTEGER NOT NULL, month INTEGER NOT NULL DEFAULT 1,
            acq_date TEXT NOT NULL DEFAULT ''
        );
        CREATE TABLE holdings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ticker_code TEXT DEFAULT '', ticker_name TEXT NOT NULL,
            account_type TEXT NOT NULL DEFAULT '特定口座',
            category TEXT NOT NULL, quantity REAL DEFAULT 0,
            avg_cost REAL DEFAULT 0, total_cost REAL DEFAULT 0,
            yf_ticker TEXT DEFAULT '', last_price REAL,
            last_updated TEXT DEFAULT '',
            UNIQUE(ticker_name, account_type)
        );
        CREATE TABLE portfolio_snapshots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            snapshot_date TEXT NOT NULL UNIQUE,
            total_assets REAL DEFAULT 0, realized_cumulative REAL DEFAULT 0,
            realized_annual REAL DEFAULT 0, unrealized_gains REAL DEFAULT 0
        );
    """)
    conn.execute("""INSERT INTO transactions
        (account_type, ticker_code, ticker_name, trade_date, trade_type, profit_type,
         quantity, sale_amount, cost_amount, profit_loss, tax, category, year, month, acq_date)
        VALUES ('特定口座', 'TST1', 'テスト銘柄A', '2024-03-15', '売却', '売却',
                '100', 250000, 200000, 50000, 10000, '国内株', 2024, 3, '2023-04-01')""")
    conn.execute("""INSERT INTO holdings
        (ticker_code, ticker_name, account_type, category, quantity, avg_cost,
         total_cost, yf_ticker, last_price, last_updated)
        VALUES ('TST1', 'テスト銘柄A', '特定口座', '国内株', 100, 2000, 200000, 'TST1.T', 2500, '2024-03-15')""")
    conn.execute("""INSERT INTO portfolio_snapshots
        (snapshot_date, total_assets, realized_cumulative, realized_annual, unrealized_gains)
        VALUES ('2024-03-15', 10000000, 500000, 100000, 200000)""")
    conn.commit()
    conn.close()


def test_export_apple_zip_creates_valid_zip(tmp_path: Path) -> None:
    db = tmp_path / "test.db"
    out_dir = tmp_path / "out"
    _seed_db(db)

    zip_path = export_apple_zip(db_path=db, out_dir=out_dir)

    assert zip_path.exists()
    assert zip_path.suffix == ".zip"
    with zipfile.ZipFile(zip_path) as z:
        names = set(z.namelist())
        assert names == {"meta.json", "transactions.csv", "holdings.csv", "snapshots.csv"}

        meta = json.loads(z.read("meta.json"))
        assert meta["schema_version"] == 1
        assert meta["tables"]["transactions"] == 1
        assert meta["tables"]["holdings"] == 1
        assert meta["tables"]["snapshots"] == 1

        tx_csv = z.read("transactions.csv").decode("utf-8-sig")
        assert "テスト銘柄A" in tx_csv
        assert "acq_date" in tx_csv


def test_export_apple_zip_handles_empty_db(tmp_path: Path) -> None:
    db = tmp_path / "empty.db"
    out_dir = tmp_path / "out"
    conn = sqlite3.connect(db)
    conn.executescript("""
        CREATE TABLE transactions (id INTEGER, account_type TEXT, ticker_code TEXT,
            ticker_name TEXT, trade_date TEXT, trade_type TEXT, profit_type TEXT,
            quantity TEXT, sale_amount INTEGER, cost_amount INTEGER,
            profit_loss INTEGER, tax INTEGER, category TEXT, year INTEGER, month INTEGER, acq_date TEXT);
        CREATE TABLE holdings (id INTEGER, ticker_code TEXT, ticker_name TEXT,
            account_type TEXT, category TEXT, quantity REAL, avg_cost REAL,
            total_cost REAL, yf_ticker TEXT, last_price REAL, last_updated TEXT);
        CREATE TABLE portfolio_snapshots (id INTEGER, snapshot_date TEXT,
            total_assets REAL, realized_cumulative REAL, realized_annual REAL, unrealized_gains REAL);
    """)
    conn.commit()
    conn.close()

    zip_path = export_apple_zip(db_path=db, out_dir=out_dir)
    with zipfile.ZipFile(zip_path) as z:
        meta = json.loads(z.read("meta.json"))
        assert meta["tables"] == {"transactions": 0, "holdings": 0, "snapshots": 0}
