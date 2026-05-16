import sqlite3

import pandas as pd
import pytest

import scripts.export_csv as export_module
from scripts.export_csv import clean_db_duplicates, export_holdings, export_transactions


def _insert_tx(conn: sqlite3.Connection, **overrides: object) -> None:
    row: dict[str, object] = {
        "account_type": "特定口座",
        "ticker_code": "1234",
        "ticker_name": "テスト株式",
        "trade_date": "2024-01-15",
        "trade_type": "配当",
        "profit_type": "配当",
        "quantity": "100",
        "sale_amount": 5000,
        "cost_amount": 0,
        "profit_loss": 5000,
        "tax": 1021,
        "category": "日本株",
        "year": 2024,
        "month": 1,
    }
    row.update(overrides)
    conn.execute(
        """INSERT INTO transactions
           (account_type, ticker_code, ticker_name, trade_date, trade_type, profit_type,
            quantity, sale_amount, cost_amount, profit_loss, tax, category, year, month)
           VALUES (:account_type, :ticker_code, :ticker_name, :trade_date, :trade_type,
                   :profit_type, :quantity, :sale_amount, :cost_amount, :profit_loss,
                   :tax, :category, :year, :month)""",
        row,
    )
    conn.commit()


def _insert_holding(conn: sqlite3.Connection, **overrides: object) -> None:
    row: dict[str, object] = {
        "ticker_code": "1234",
        "ticker_name": "テスト株式",
        "account_type": "特定口座",
        "category": "日本株",
        "quantity": 100.0,
        "avg_cost": 1500.0,
        "total_cost": 150000.0,
        "yf_ticker": "1234.T",
    }
    row.update(overrides)
    conn.execute(
        """INSERT INTO holdings
           (ticker_code, ticker_name, account_type, category, quantity, avg_cost, total_cost, yf_ticker)
           VALUES (:ticker_code, :ticker_name, :account_type, :category,
                   :quantity, :avg_cost, :total_cost, :yf_ticker)""",
        row,
    )
    conn.commit()


@pytest.fixture()
def tmp_exports(tmp_path: object, monkeypatch: pytest.MonkeyPatch) -> object:
    monkeypatch.setattr(export_module, "EXPORTS", tmp_path)
    return tmp_path


# ── export_transactions ───────────────────────────────────────────────────────

class TestExportTransactions:
    def test_writes_csv(self, mem_conn: sqlite3.Connection, tmp_exports: object) -> None:
        _insert_tx(mem_conn)
        count = export_transactions(mem_conn)
        assert count == 1
        import pathlib
        csv = pathlib.Path(str(tmp_exports)) / "transactions.csv"
        assert csv.exists()
        df = pd.read_csv(csv, encoding="utf-8-sig")
        assert len(df) == 1
        assert df.iloc[0]["ticker_name"] == "テスト株式"

    def test_deduplicates_on_export(self, mem_conn_no_unique: sqlite3.Connection, tmp_exports: object) -> None:
        # UNIQUEインデックスなしのDBで重複行を挿入し、エクスポート時に除去されることを確認
        _insert_tx(mem_conn_no_unique)
        _insert_tx(mem_conn_no_unique)
        count = export_transactions(mem_conn_no_unique)
        assert count == 1  # drop_duplicatesで1件に

    def test_exports_correct_columns(self, mem_conn: sqlite3.Connection, tmp_exports: object) -> None:
        _insert_tx(mem_conn)
        export_transactions(mem_conn)
        import pathlib
        df = pd.read_csv(pathlib.Path(str(tmp_exports)) / "transactions.csv", encoding="utf-8-sig")
        expected = {
            "account_type", "ticker_code", "ticker_name", "trade_date",
            "trade_type", "profit_type", "quantity",
            "sale_amount", "cost_amount", "profit_loss", "tax", "category",
        }
        assert expected <= set(df.columns)


# ── export_holdings ───────────────────────────────────────────────────────────

class TestExportHoldings:
    def test_writes_csv(self, mem_conn: sqlite3.Connection, tmp_exports: object) -> None:
        _insert_holding(mem_conn)
        count = export_holdings(mem_conn)
        assert count == 1
        import pathlib
        csv = pathlib.Path(str(tmp_exports)) / "holdings.csv"
        assert csv.exists()
        df = pd.read_csv(csv, encoding="utf-8-sig")
        assert df.iloc[0]["ticker_name"] == "テスト株式"

    def test_empty_table_writes_empty_csv(self, mem_conn: sqlite3.Connection, tmp_exports: object) -> None:
        count = export_holdings(mem_conn)
        assert count == 0


# ── clean_db_duplicates ───────────────────────────────────────────────────────

class TestCleanDbDuplicates:
    def test_removes_duplicates_keeps_min_id(self, mem_conn_no_unique: sqlite3.Connection) -> None:
        _insert_tx(mem_conn_no_unique)
        _insert_tx(mem_conn_no_unique)
        removed = clean_db_duplicates(mem_conn_no_unique)
        assert removed == 1
        count = mem_conn_no_unique.execute("SELECT COUNT(*) FROM transactions").fetchone()[0]
        assert count == 1

    def test_no_duplicates_removes_nothing(self, mem_conn: sqlite3.Connection) -> None:
        _insert_tx(mem_conn, sale_amount=1000)
        _insert_tx(mem_conn, sale_amount=2000)
        removed = clean_db_duplicates(mem_conn)
        assert removed == 0

    def test_empty_table_removes_nothing(self, mem_conn: sqlite3.Connection) -> None:
        removed = clean_db_duplicates(mem_conn)
        assert removed == 0
