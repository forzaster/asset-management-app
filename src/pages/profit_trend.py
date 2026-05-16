import plotly.express as px
import plotly.graph_objects as go
import streamlit as st

from core.db import query_df

CATEGORY_COLORS = {
    "日本株": "#1f77b4",
    "投資信託": "#ff7f0e",
    "外国株ETF": "#2ca02c",
    "REIT": "#d62728",
    "外国投信": "#9467bd",
}
CATEGORY_ORDER = ["日本株", "REIT", "外国株ETF", "外国投信", "投資信託"]

st.title("📈 利益推移")


@st.cache_data(ttl=300)
def load_annual():
    return query_df("""
        SELECT year, category, profit_type, SUM(profit_loss) AS pl, SUM(tax) AS total_tax
        FROM transactions
        GROUP BY year, category, profit_type
        ORDER BY year, category, profit_type
    """)

df = load_annual()
if df.empty:
    st.warning("データがありません。設定画面からデータをインポートしてください。")
    st.stop()

# ── フィルター ──────────────────────────────────────────────────────────────────
all_cats  = sorted(df["category"].unique().tolist())
all_years = sorted(df["year"].unique().tolist())

with st.sidebar:
    st.subheader("フィルター")
    sel_cats = st.multiselect("投資分類", all_cats, default=all_cats)
    sel_years = st.slider("年範囲", min(all_years), max(all_years),
                          (min(all_years), max(all_years)))
    sel_ptypes = st.multiselect("利益種別", ["配当", "売却"], default=["配当", "売却"])

mask = (
    df["category"].isin(sel_cats) &
    df["year"].between(*sel_years) &
    df["profit_type"].isin(sel_ptypes)
)
df_f = df[mask].copy()

# ── 年次損益推移チャート (stacked bar, faceted by profit_type) ─────────────────
st.subheader("年次損益推移（投資分類別）")

if df_f.empty:
    st.info("条件に合うデータがありません")
else:
    cat_order_filtered = [c for c in CATEGORY_ORDER if c in sel_cats]
    fig = px.bar(
        df_f,
        x="year", y="pl", color="category",
        facet_col="profit_type",
        barmode="stack",
        color_discrete_map=CATEGORY_COLORS,
        category_orders={"category": cat_order_filtered, "profit_type": sel_ptypes},
        labels={"pl": "損益（円）", "year": "年", "category": "分類", "profit_type": "種別"},
        height=420,
    )
    fig.update_layout(
        yaxis_tickformat=",.0f",
        hovermode="x unified",
        legend_title="投資分類",
    )
    fig.add_hline(y=0, line_dash="dash", line_color="gray", line_width=1)
    fig.for_each_annotation(lambda a: a.update(text=a.text.split("=")[-1]))
    st.plotly_chart(fig, use_container_width=True)

# ── 累積損益推移チャート ──────────────────────────────────────────────────────────
st.subheader("累積損益推移")

@st.cache_data(ttl=300)
def load_cumulative():
    return query_df("""
        SELECT year, SUM(profit_loss) AS annual_pl, SUM(tax) AS annual_tax
        FROM transactions
        GROUP BY year ORDER BY year
    """)

df_cum = load_cumulative()
df_cum = df_cum[df_cum["year"].between(*sel_years)].copy()
df_cum["cumulative"] = df_cum["annual_pl"].cumsum()
df_cum["cumulative_tax"] = df_cum["annual_tax"].cumsum()
df_cum["cumulative_net"] = df_cum["cumulative"] - df_cum["cumulative_tax"]

fig2 = go.Figure()
fig2.add_bar(
    x=df_cum["year"], y=df_cum["annual_pl"],
    name="年次損益", marker_color="#90CAF9", opacity=0.6,
)
fig2.add_bar(
    x=df_cum["year"], y=-df_cum["annual_tax"],
    name="税金（控除）", marker_color="#FFCDD2", opacity=0.6,
)
fig2.add_scatter(
    x=df_cum["year"], y=df_cum["cumulative"],
    mode="lines+markers", name="累積損益（税引前）", line=dict(color="#1565C0", width=2),
)
fig2.add_scatter(
    x=df_cum["year"], y=df_cum["cumulative_net"],
    mode="lines+markers", name="累積損益（税引後）",
    line=dict(color="#E53935", width=2, dash="dot"),
)
fig2.add_hline(y=0, line_dash="dash", line_color="gray", line_width=1)
fig2.update_layout(
    yaxis_tickformat=",.0f",
    xaxis_title="年", yaxis_title="損益（円）",
    hovermode="x unified", height=380,
    barmode="overlay",
    legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1),
)
st.plotly_chart(fig2, use_container_width=True)

# ── 年次サマリーテーブル ───────────────────────────────────────────────────────────
st.subheader("年次サマリー")

pivot = df_f.pivot_table(
    index="year", columns="profit_type", values="pl", aggfunc="sum", fill_value=0
).reset_index()
pivot["損益合計"] = pivot.drop(columns="year").sum(axis=1)
tax_by_year = df_f.groupby("year")["total_tax"].sum().reset_index().rename(columns={"total_tax": "税金"})
pivot = pivot.merge(tax_by_year, on="year", how="left").fillna(0)
pivot["税引後合計"] = pivot["損益合計"] - pivot["税金"]
pivot = pivot.sort_values("year", ascending=False)

col_cfg: dict = {
    "year":    st.column_config.NumberColumn("年", format="%d"),
    "損益合計": st.column_config.NumberColumn("損益合計（円）",  format="¥%,.0f"),
    "税金":    st.column_config.NumberColumn("税金（円）",      format="¥%,.0f"),
    "税引後合計": st.column_config.NumberColumn("税引後合計（円）", format="¥%,.0f"),
}
for pt in ["配当", "売却"]:
    if pt in pivot.columns:
        col_cfg[pt] = st.column_config.NumberColumn(f"{pt}（円）", format="¥%,.0f")

st.dataframe(pivot, column_config=col_cfg, hide_index=True, use_container_width=True)

# ── カテゴリ別累積サマリー ──────────────────────────────────────────────────────────
st.subheader("投資分類別 累積損益サマリー")
cat_pivot = df_f.pivot_table(
    index="category", columns="profit_type", values="pl", aggfunc="sum", fill_value=0
).reset_index()
cat_pivot["損益合計"] = cat_pivot.drop(columns="category").sum(axis=1)
cat_tax = df_f.groupby("category")["total_tax"].sum().reset_index().rename(columns={"total_tax": "税金"})
cat_pivot = cat_pivot.merge(cat_tax, on="category", how="left").fillna(0)
cat_pivot["税引後合計"] = cat_pivot["損益合計"] - cat_pivot["税金"]
cat_pivot = cat_pivot.sort_values("損益合計", ascending=False)

cat_col_cfg: dict = {
    "category": st.column_config.TextColumn("投資分類"),
    "損益合計":  st.column_config.NumberColumn("損益合計（円）",  format="¥%,.0f"),
    "税金":     st.column_config.NumberColumn("税金（円）",      format="¥%,.0f"),
    "税引後合計": st.column_config.NumberColumn("税引後合計（円）", format="¥%,.0f"),
}
for pt in ["配当", "売却"]:
    if pt in cat_pivot.columns:
        cat_col_cfg[pt] = st.column_config.NumberColumn(f"{pt}（円）", format="¥%,.0f")

st.dataframe(cat_pivot, column_config=cat_col_cfg, hide_index=True, use_container_width=True)
