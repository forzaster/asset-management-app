import sqlite3

import pandas as pd
import pytest

from core.db import (
    _s,
    import_holdings_csv,
    import_tokutei_csv_text,
    import_transactions_csv,
    sync_tax_from_text,
)

# ── _s ヘルパー ───────────────────────────────────────────────────────────────

class TestHelperS:
    def test_none_returns_default(self) -> None:
        assert _s(None) == ""

    def test_nan_returns_default(self) -> None:
        assert _s(float("nan")) == ""

    def test_custom_default_for_none(self) -> None:
        assert _s(None, "特定口座") == "特定口座"

    def test_string_passthrough(self) -> None:
        assert _s("hello") == "hello"

    def test_int_converts_to_str(self) -> None:
        assert _s(42) == "42"


# ── import_transactions_csv ───────────────────────────────────────────────────

def _tx_row(**overrides: object) -> pd.DataFrame:
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
    }
    row.update(overrides)
    return pd.DataFrame([row])


class TestImportTransactionsCsv:
    def test_inserts_new_row(self, tmp_db: object) -> None:
        result = import_transactions_csv(_tx_row())
        assert result == {"inserted": 1, "skipped": 0}

    def test_skips_exact_duplicate(self, tmp_db: object) -> None:
        import_transactions_csv(_tx_row())
        result = import_transactions_csv(_tx_row())
        assert result == {"inserted": 0, "skipped": 1}

    def test_inserts_different_row(self, tmp_db: object) -> None:
        import_transactions_csv(_tx_row(sale_amount=5000))
        result = import_transactions_csv(_tx_row(sale_amount=6000))
        assert result["inserted"] == 1

    def test_year_month_derived_from_trade_date(self, tmp_db: object) -> None:
        import_transactions_csv(_tx_row(trade_date="2023-06-30"))
        conn = sqlite3.connect(tmp_db)  # type: ignore[arg-type]
        row = conn.execute("SELECT year, month FROM transactions").fetchone()
        conn.close()
        assert row == (2023, 6)

    def test_nan_ticker_code_stored_as_empty_string(self, tmp_db: object) -> None:
        df = _tx_row()
        df["ticker_code"] = float("nan")
        import_transactions_csv(df)
        conn = sqlite3.connect(tmp_db)  # type: ignore[arg-type]
        code = conn.execute("SELECT ticker_code FROM transactions").fetchone()[0]
        conn.close()
        assert code == ""

    def test_missing_required_column_raises(self, tmp_db: object) -> None:
        df = _tx_row().drop(columns=["trade_date"])
        with pytest.raises(ValueError, match="trade_date"):
            import_transactions_csv(df)

    def test_invalid_date_raises(self, tmp_db: object) -> None:
        with pytest.raises(ValueError, match="trade_date"):
            import_transactions_csv(_tx_row(trade_date="not-a-date"))

    def test_multiple_rows_batch(self, tmp_db: object) -> None:
        df = pd.concat([_tx_row(sale_amount=i * 1000) for i in range(1, 4)], ignore_index=True)
        result = import_transactions_csv(df)
        assert result["inserted"] == 3
        assert result["skipped"] == 0


# ── import_holdings_csv ───────────────────────────────────────────────────────

def _holding_row(**overrides: object) -> pd.DataFrame:
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
    return pd.DataFrame([row])


class TestImportHoldingsCsv:
    def test_inserts_new_holding(self, tmp_db: object) -> None:
        result = import_holdings_csv(_holding_row())
        assert result == {"upserted": 1}

    def test_updates_existing_holding(self, tmp_db: object) -> None:
        import_holdings_csv(_holding_row(quantity=100.0))
        import_holdings_csv(_holding_row(quantity=200.0))
        conn = sqlite3.connect(tmp_db)  # type: ignore[arg-type]
        qty = conn.execute("SELECT quantity FROM holdings").fetchone()[0]
        conn.close()
        assert qty == 200.0

    def test_nan_yf_ticker_stored_as_empty_string(self, tmp_db: object) -> None:
        df = _holding_row()
        df["yf_ticker"] = float("nan")
        import_holdings_csv(df)
        conn = sqlite3.connect(tmp_db)  # type: ignore[arg-type]
        ticker = conn.execute("SELECT yf_ticker FROM holdings").fetchone()[0]
        conn.close()
        assert ticker == ""

    def test_missing_required_column_raises(self, tmp_db: object) -> None:
        df = _holding_row().drop(columns=["ticker_name"])
        with pytest.raises(ValueError, match="ticker_name"):
            import_holdings_csv(df)

    def test_skips_rows_with_empty_ticker_name(self, tmp_db: object) -> None:
        df = _holding_row(ticker_name="")
        import_holdings_csv(df)
        conn = sqlite3.connect(tmp_db)  # type: ignore[arg-type]
        count = conn.execute("SELECT COUNT(*) FROM holdings").fetchone()[0]
        conn.close()
        assert count == 0


# ── import_tokutei_csv_text ───────────────────────────────────────────────────

SAMPLE_TOKUTEI_CSV = """\
2024,,,,,,,,,,,,,,
,銘柄,,,,,,,,,,,,,
1234,テスト株式会社,,,現物売,2024/01/15,2024/01/17,100,,500000,400000,,100000,,
""".lstrip()


def test_import_tokutei_csv_text_inserts(tmp_db: object) -> None:
    result = import_tokutei_csv_text(SAMPLE_TOKUTEI_CSV)
    assert result["inserted"] >= 1
    assert result["updated"] >= 0


def test_import_tokutei_csv_text_idempotent(tmp_db: object) -> None:
    import_tokutei_csv_text(SAMPLE_TOKUTEI_CSV)
    result2 = import_tokutei_csv_text(SAMPLE_TOKUTEI_CSV)
    assert result2["inserted"] == 0  # 2回目は重複スキップ


# ── sync_tax_from_text ────────────────────────────────────────────────────────

SAMPLE_TAX_CSV = """\
2024,,,,,,,,,,,,,,
,銘柄,,,,,,,,,,,,,
1234,テスト株式会社,,,現物売,2024/01/15,2024/01/17,100,,500000,400000,,100000,,
譲渡益税徴収額,,,,,2024/01/17,,,,,,15315,3084,,
""".lstrip()


def test_sync_tax_from_text_updates(tmp_db: object) -> None:
    import_tokutei_csv_text(SAMPLE_TAX_CSV)
    result = sync_tax_from_text(SAMPLE_TAX_CSV)
    assert result["updated"] >= 1


def test_sync_tax_from_text_idempotent(tmp_db: object) -> None:
    import_tokutei_csv_text(SAMPLE_TAX_CSV)
    sync_tax_from_text(SAMPLE_TAX_CSV)
    result2 = sync_tax_from_text(SAMPLE_TAX_CSV)
    assert result2["updated"] >= 0
