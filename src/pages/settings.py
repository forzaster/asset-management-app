import io

import pandas as pd
import streamlit as st

from core.db import (
    get_db,
    import_holdings_csv,
    import_transactions_csv,
    query_df,
)

st.title("⚙️ 設定")


# ── 取引履歴 CSVインポート ──────────────────────────────────────────────────────
st.subheader("取引履歴インポート")
st.caption(
    "フォーマット: account_type, ticker_code, ticker_name, trade_date, trade_type, "
    "profit_type, quantity, sale_amount, cost_amount, profit_loss, tax, category"
)

tx_file = st.file_uploader("transactions.csv を選択", type="csv", key="tx_uploader")

if tx_file is not None:
    try:
        df_tx = pd.read_csv(tx_file, encoding="utf-8-sig")
    except Exception:
        tx_file.seek(0)
        df_tx = pd.read_csv(tx_file, encoding="utf-8")

    st.write("**プレビュー（先頭5行）**")
    st.dataframe(df_tx.head(), use_container_width=True)
    st.caption(f"合計 {len(df_tx):,} 行")

    if st.button("📥 取引履歴をインポート", type="primary", key="tx_import"):
        try:
            with st.spinner("インポート中…"):
                result = import_transactions_csv(df_tx)
            st.success(f"完了 — 追加 {result['inserted']:,} 件 / スキップ（重複） {result['skipped']:,} 件")
            st.cache_data.clear()
        except ValueError as e:
            st.error(f"フォーマットエラー: {e}")

st.divider()


# ── 保有銘柄 CSVインポート ─────────────────────────────────────────────────────
st.subheader("保有銘柄インポート")
st.caption(
    "フォーマット: ticker_code, ticker_name, account_type, category, "
    "quantity, avg_cost, total_cost, yf_ticker"
)

h_file = st.file_uploader("holdings.csv を選択", type="csv", key="h_uploader")

if h_file is not None:
    try:
        df_h_upload = pd.read_csv(h_file, encoding="utf-8-sig")
    except Exception:
        h_file.seek(0)
        df_h_upload = pd.read_csv(h_file, encoding="utf-8")

    st.write("**プレビュー（先頭5行）**")
    st.dataframe(df_h_upload.head(), use_container_width=True)
    st.caption(f"合計 {len(df_h_upload):,} 行")

    if st.button("📥 保有銘柄をインポート", type="primary", key="h_import"):
        try:
            with st.spinner("インポート中…"):
                result = import_holdings_csv(df_h_upload)
            st.success(f"完了 — {result['upserted']:,} 件を更新しました")
            st.cache_data.clear()
        except ValueError as e:
            st.error(f"フォーマットエラー: {e}")

st.divider()


# ── 保有銘柄管理（手動編集） ───────────────────────────────────────────────────
st.subheader("保有銘柄管理")
st.caption("保有数量・平均取得単価・yfinanceティッカーを直接編集できます。")

@st.cache_data(ttl=30)
def load_holdings_edit():
    return query_df("""
        SELECT id, ticker_code, ticker_name, account_type, category,
               quantity, avg_cost, total_cost, yf_ticker
        FROM holdings ORDER BY category, account_type, ticker_name
    """)

df_h = load_holdings_edit()

edited = st.data_editor(
    df_h,
    column_config={
        "id":           st.column_config.NumberColumn("ID",   disabled=True, width="small"),
        "ticker_code":  st.column_config.TextColumn("コード", width="small"),
        "ticker_name":  st.column_config.TextColumn("銘柄名", width="large"),
        "account_type": st.column_config.SelectboxColumn(
            "口座", options=["特定口座", "NISA", "一般"], width="small"
        ),
        "category":     st.column_config.SelectboxColumn(
            "分類",
            options=["日本株", "投資信託", "外国株ETF", "REIT", "外国投信"],
            width="small",
        ),
        "quantity":     st.column_config.NumberColumn("保有数量",     format="%.0f"),
        "avg_cost":     st.column_config.NumberColumn("平均取得単価", format="¥%.0f"),
        "total_cost":   st.column_config.NumberColumn("取得総額",     format="¥%.0f"),
        "yf_ticker":    st.column_config.TextColumn("YFティッカー",   width="small"),
    },
    hide_index=True,
    num_rows="dynamic",
    use_container_width=True,
    key="holdings_editor",
)

col_save, col_csv = st.columns([1, 1])

with col_save:
    if st.button("💾 保有銘柄を保存", use_container_width=True):
        with get_db() as conn:
            conn.execute("DELETE FROM holdings")
            conn.executemany(
                """INSERT INTO holdings
                   (ticker_code, ticker_name, account_type, category,
                    quantity, avg_cost, total_cost, yf_ticker)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
                [
                    (
                        str(r.get("ticker_code", "") or ""),
                        str(r.get("ticker_name", "") or ""),
                        str(r.get("account_type", "特定口座")),
                        str(r.get("category", "日本株")),
                        float(r.get("quantity", 0) or 0),
                        float(r.get("avg_cost", 0) or 0),
                        float(r.get("total_cost", 0) or 0),
                        str(r.get("yf_ticker", "") or ""),
                    )
                    for _, r in edited.iterrows()
                    if str(r.get("ticker_name", "")).strip()
                ],
            )
        load_holdings_edit.clear()
        st.success("保存しました。")

with col_csv:
    buf = io.StringIO()
    df_h.to_csv(buf, index=False, encoding="utf-8-sig")
    st.download_button(
        "📥 CSVエクスポート",
        data=buf.getvalue().encode("utf-8-sig"),
        file_name="holdings.csv",
        mime="text/csv",
        use_container_width=True,
    )

st.divider()

# ── データ統計 ────────────────────────────────────────────────────────────────
st.subheader("データ統計")
stats = query_df("""
    SELECT
        (SELECT COUNT(*) FROM transactions) AS tx_count,
        (SELECT MIN(trade_date) FROM transactions) AS first_date,
        (SELECT MAX(trade_date) FROM transactions) AS last_date,
        (SELECT COUNT(*) FROM holdings) AS holding_count,
        (SELECT COUNT(*) FROM portfolio_snapshots) AS snap_count
""")
if not stats.empty:
    r = stats.iloc[0]
    col1, col2, col3, col4, col5 = st.columns(5)
    col1.metric("取引件数",    f"{int(r['tx_count']):,}")
    col2.metric("最初の取引", r["first_date"])
    col3.metric("最後の取引", r["last_date"])
    col4.metric("保有銘柄数", int(r["holding_count"]))
    col5.metric("推移スナップ", int(r["snap_count"]))
