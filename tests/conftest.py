import sqlite3

import pytest

import core.db as db_module


@pytest.fixture()
def tmp_db(tmp_path, monkeypatch):
    """DB_PATH を一時ファイルに差し替えてスキーマを初期化する。"""
    db_path = tmp_path / "test.db"
    monkeypatch.setattr(db_module, "DB_PATH", db_path)
    db_module.init_db()
    return db_path


_SCHEMA_NO_UNIQUE = """
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
    yf_ticker    TEXT DEFAULT ''
);
"""


@pytest.fixture()
def mem_conn():
    """スキーマ適用済みのインメモリSQLite接続（export_csv テスト用）。"""
    conn = sqlite3.connect(":memory:")
    conn.executescript(db_module._SCHEMA)
    yield conn
    conn.close()


@pytest.fixture()
def mem_conn_no_unique():
    """UNIQUEインデックスなしのインメモリSQLite接続（重複挿入テスト用）。"""
    conn = sqlite3.connect(":memory:")
    conn.executescript(_SCHEMA_NO_UNIQUE)
    yield conn
    conn.close()
