from datetime import datetime

import pandas as pd
import plotly.express as px
import streamlit as st
import yfinance as yf

from core.db import get_db, query_df

CATEGORY_COLORS = {
    "日本株": "#1f77b4",
    "投資信託": "#ff7f0e",
    "外国株ETF": "#2ca02c",
    "REIT": "#d62728",
    "外国投信": "#9467bd",
}

st.title("📊 ホーム — 最新ステータス")


# ── KPI 集計 ──────────────────────────────────────────────────────────────────
@st.cache_data(ttl=300)
def load_kpis():
    df = query_df("""
        SELECT year, profit_type, SUM(profit_loss) AS pl
        FROM transactions GROUP BY year, profit_type
    """)
    total_pl   = int(df["pl"].sum())
    div_total  = int(df.loc[df["profit_type"] == "配当",  "pl"].sum())
    sell_total = int(df.loc[df["profit_type"] == "売却", "pl"].sum())

    max_year = int(df["year"].max()) if not df.empty else datetime.now().year
    yr = df[df["year"] == max_year]
    yr_pl   = int(yr["pl"].sum())
    yr_div  = int(yr.loc[yr["profit_type"] == "配当",  "pl"].sum())
    yr_sell = int(yr.loc[yr["profit_type"] == "売却", "pl"].sum())
    return total_pl, div_total, sell_total, yr_pl, yr_div, yr_sell, max_year

total_pl, div_total, sell_total, yr_pl, yr_div, yr_sell, max_year = load_kpis()

c1, c2, c3, c4, c5, c6 = st.columns(6)
c1.metric("累積損益合計",       f"¥{total_pl:,}")
c2.metric("うち配当累計",       f"¥{div_total:,}")
c3.metric("うち売却損益累計",   f"¥{sell_total:,}")
c4.metric(f"{max_year}年 損益", f"¥{yr_pl:,}")
c5.metric(f"{max_year}年 配当", f"¥{yr_div:,}")
c6.metric(f"{max_year}年 売却", f"¥{yr_sell:,}")

st.divider()


# ── 累積損益内訳チャート ───────────────────────────────────────────────────────
@st.cache_data(ttl=300)
def load_category_summary():
    return query_df("""
        SELECT category, profit_type, SUM(profit_loss) AS pl
        FROM transactions GROUP BY category, profit_type
    """)

df_cat = load_category_summary()
df_cat_pos = df_cat[df_cat["pl"] > 0]

col_l, col_r = st.columns(2)
with col_l:
    st.subheader("投資分類別 累積損益")
    if not df_cat_pos.empty:
        cat_sum = df_cat_pos.groupby("category")["pl"].sum().reset_index()
        fig = px.pie(
            cat_sum, names="category", values="pl",
            color="category", color_discrete_map=CATEGORY_COLORS,
            hole=0.4,
        )
        fig.update_traces(textposition="inside", textinfo="percent+label")
        fig.update_layout(showlegend=False, margin=dict(t=0, b=0, l=0, r=0), height=300)
        st.plotly_chart(fig, use_container_width=True)

with col_r:
    st.subheader("配当 / 売却損益 内訳")
    ptype_sum = df_cat.groupby("profit_type")["pl"].sum().reset_index()
    fig2 = px.pie(
        ptype_sum, names="profit_type", values="pl",
        color="profit_type",
        color_discrete_map={"配当": "#4CAF50", "売却": "#2196F3"},
        hole=0.4,
    )
    fig2.update_traces(textposition="inside", textinfo="percent+label")
    fig2.update_layout(showlegend=False, margin=dict(t=0, b=0, l=0, r=0), height=300)
    st.plotly_chart(fig2, use_container_width=True)

st.divider()


# ── 保有銘柄一覧 ───────────────────────────────────────────────────────────────
st.subheader("保有銘柄一覧")

@st.cache_data(ttl=60)
def load_holdings() -> pd.DataFrame:
    return query_df("""
        SELECT id, ticker_code, ticker_name, account_type, category,
               quantity, avg_cost, total_cost, yf_ticker, last_price, last_updated
        FROM holdings ORDER BY category, account_type, ticker_name
    """)

df_hold = load_holdings()

btn_col, info_col = st.columns([1, 5])
with btn_col:
    fetch = st.button("🔄 株価 Fetch", use_container_width=True)

if fetch:
    tickers = df_hold[df_hold["yf_ticker"].str.strip() != ""]["yf_ticker"].unique().tolist()
    if tickers:
        with st.spinner(f"{len(tickers)}銘柄の株価を取得中…"):
            try:
                raw = yf.download(
                    tickers, period="2d", auto_adjust=True,
                    progress=False, threads=True,
                )
                prices = {}
                close = raw["Close"] if "Close" in raw.columns else raw
                latest = close.iloc[-1] if not close.empty else pd.Series(dtype=float)
                for tkr in tickers:
                    if tkr in latest.index:
                        prices[tkr] = float(latest[tkr])

                now_str = datetime.now().strftime("%Y-%m-%d %H:%M")
                with get_db() as conn:
                    for tkr, price in prices.items():
                        conn.execute(
                            "UPDATE holdings SET last_price=?, last_updated=? WHERE yf_ticker=?",
                            (price, now_str, tkr),
                        )
                load_holdings.clear()
                df_hold = load_holdings()
                st.success(f"{len(prices)}銘柄の株価を更新しました（{now_str}）")
            except Exception as e:
                st.error(f"取得失敗: {e}")
    else:
        st.info("yfinanceティッカーが設定されている銘柄がありません")

with info_col:
    last = df_hold["last_updated"].dropna()
    last = last[last != ""]
    if not last.empty:
        st.caption(f"最終更新: {last.max()}")

# 含み損益計算
df_view = df_hold.copy()
df_view["現在値"] = df_view["last_price"]
df_view["評価額"] = df_view.apply(
    lambda r: r["quantity"] * r["last_price"]
    if pd.notna(r["last_price"]) and r["quantity"] > 0 else None,
    axis=1,
)
df_view["含み損益"] = df_view.apply(
    lambda r: r["評価額"] - r["total_cost"]
    if pd.notna(r["評価額"]) and r["total_cost"] > 0 else None,
    axis=1,
)

display_df = df_view[[
    "ticker_code", "ticker_name", "account_type", "category",
    "quantity", "avg_cost", "現在値", "評価額", "含み損益", "yf_ticker",
]].rename(columns={
    "ticker_code": "コード",
    "ticker_name": "銘柄名",
    "account_type": "口座",
    "category":    "分類",
    "quantity":    "保有数量",
    "avg_cost":    "平均取得単価",
    "yf_ticker":   "YFティッカー",
})

st.dataframe(
    display_df,
    column_config={
        "コード":       st.column_config.TextColumn(width="small"),
        "銘柄名":       st.column_config.TextColumn(width="large"),
        "口座":         st.column_config.TextColumn(width="small"),
        "分類":         st.column_config.TextColumn(width="small"),
        "保有数量":     st.column_config.NumberColumn(format="%.0f"),
        "平均取得単価": st.column_config.NumberColumn(format="¥%.0f"),
        "現在値":       st.column_config.NumberColumn(format="¥%.0f"),
        "評価額":       st.column_config.NumberColumn(format="¥%.0f"),
        "含み損益":     st.column_config.NumberColumn(format="¥%.0f"),
        "YFティッカー": st.column_config.TextColumn(width="small"),
    },
    hide_index=True,
    use_container_width=True,
)
