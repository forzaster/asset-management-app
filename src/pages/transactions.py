import io

import pandas as pd
import streamlit as st

from core.db import query_df

st.title("📋 取引履歴")


@st.cache_data(ttl=300)
def load_all() -> pd.DataFrame:
    return query_df("""
        SELECT trade_date, year, month, account_type, ticker_code, ticker_name,
               category, profit_type, trade_type, quantity,
               sale_amount, cost_amount, profit_loss, tax
        FROM transactions
        ORDER BY trade_date DESC, id DESC
    """)

df = load_all()
if df.empty:
    st.warning("データがありません。設定画面からインポートしてください。")
    st.stop()

# ── フィルター ──────────────────────────────────────────────────────────────────
with st.sidebar:
    st.subheader("フィルター")
    years    = sorted(df["year"].unique().tolist(), reverse=True)
    accounts = sorted(df["account_type"].unique().tolist())
    cats     = sorted(df["category"].unique().tolist())
    ptypes   = sorted(df["profit_type"].unique().tolist())

    sel_years    = st.multiselect("年",       ["全て"] + [str(y) for y in years], default=["全て"])
    sel_accounts = st.multiselect("口座",     accounts, default=accounts)
    sel_cats     = st.multiselect("投資分類", cats,     default=cats)
    sel_ptypes   = st.multiselect("利益種別", ptypes,   default=ptypes)
    keyword      = st.text_input("銘柄名検索", "")

# Apply filters
mask = (
    df["account_type"].isin(sel_accounts) &
    df["category"].isin(sel_cats) &
    df["profit_type"].isin(sel_ptypes)
)
if "全て" not in sel_years and sel_years:
    mask &= df["year"].astype(str).isin(sel_years)
if keyword:
    mask &= df["ticker_name"].str.contains(keyword, case=False, na=False)

df_f = df[mask].copy()

# ── サマリー ────────────────────────────────────────────────────────────────────
c1, c2, c3, c4 = st.columns(4)
c1.metric("件数",    f"{len(df_f):,}")
c2.metric("損益合計", f"¥{int(df_f['profit_loss'].sum()):,}")
c3.metric("うち配当", f"¥{int(df_f.loc[df_f['profit_type']=='配当', 'profit_loss'].sum()):,}")
c4.metric("うち売却", f"¥{int(df_f.loc[df_f['profit_type']=='売却', 'profit_loss'].sum()):,}")

st.divider()

# ── テーブル ────────────────────────────────────────────────────────────────────
display = df_f[[
    "trade_date", "account_type", "ticker_code", "ticker_name", "category",
    "profit_type", "quantity", "sale_amount", "cost_amount", "profit_loss", "tax",
]].rename(columns={
    "trade_date":  "取引日",
    "account_type":"口座",
    "ticker_code": "コード",
    "ticker_name": "銘柄名",
    "category":    "分類",
    "profit_type": "種別",
    "quantity":    "数量",
    "sale_amount": "売却/配当額",
    "cost_amount": "取得額",
    "profit_loss": "損益",
    "tax":         "税金",
})

st.dataframe(
    display,
    column_config={
        "取引日":     st.column_config.DateColumn(format="YYYY/MM/DD"),
        "口座":       st.column_config.TextColumn(width="small"),
        "コード":     st.column_config.TextColumn(width="small"),
        "銘柄名":     st.column_config.TextColumn(width="medium"),
        "分類":       st.column_config.TextColumn(width="small"),
        "種別":       st.column_config.TextColumn(width="small"),
        "数量":       st.column_config.TextColumn(width="small"),
        "売却/配当額":st.column_config.NumberColumn(format="¥%,.0f"),
        "取得額":     st.column_config.NumberColumn(format="¥%,.0f"),
        "損益":       st.column_config.NumberColumn(format="¥%,.0f"),
        "税金":       st.column_config.NumberColumn(format="¥%,.0f"),
    },
    hide_index=True,
    use_container_width=True,
    height=500,
)

# ── CSV エクスポート ─────────────────────────────────────────────────────────────
buf = io.StringIO()
df_f.to_csv(buf, index=False, encoding="utf-8-sig")
st.download_button(
    label="📥 CSVダウンロード",
    data=buf.getvalue().encode("utf-8-sig"),
    file_name="transactions.csv",
    mime="text/csv",
)
