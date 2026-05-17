import streamlit as st

from core.db import init_db

st.set_page_config(
    page_title="資産管理",
    page_icon="📊",
    layout="wide",
    initial_sidebar_state="expanded",
)

init_db()

home     = st.Page("pages/home.py",         title="ホーム",    icon="🏠", default=True)
trend    = st.Page("pages/profit_trend.py", title="利益推移",  icon="📈")
txns     = st.Page("pages/transactions.py", title="取引履歴",  icon="📋")
settings = st.Page("pages/settings.py",     title="データ管理", icon="🗄️")

pg = st.navigation([home, trend, txns, settings])
pg.run()
