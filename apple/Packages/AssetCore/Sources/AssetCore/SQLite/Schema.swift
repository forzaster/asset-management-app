import Foundation
import GRDB

public enum Schema {
    public static func migrate(_ writer: any DatabaseWriter) throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_initial_schema") { db in
            try db.execute(sql: """
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
                    month        INTEGER NOT NULL DEFAULT 1,
                    acq_date     TEXT NOT NULL DEFAULT ''
                )
            """)
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS holdings (
                    id           INTEGER PRIMARY KEY AUTOINCREMENT,
                    ticker_code  TEXT DEFAULT '',
                    ticker_name  TEXT NOT NULL,
                    account_type TEXT NOT NULL DEFAULT '特定口座',
                    category     TEXT NOT NULL,
                    quantity     REAL DEFAULT 0,
                    avg_cost     REAL DEFAULT 0,
                    total_cost   REAL DEFAULT 0,
                    yf_ticker    TEXT DEFAULT '',
                    last_price   REAL,
                    last_updated TEXT DEFAULT '',
                    UNIQUE(ticker_name, account_type)
                )
            """)
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS portfolio_snapshots (
                    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
                    snapshot_date       TEXT NOT NULL UNIQUE,
                    total_assets        REAL DEFAULT 0,
                    realized_cumulative REAL DEFAULT 0,
                    realized_annual     REAL DEFAULT 0,
                    unrealized_gains    REAL DEFAULT 0
                )
            """)
            try db.execute(sql: """
                CREATE UNIQUE INDEX IF NOT EXISTS uq_transaction
                ON transactions(account_type, ticker_code, ticker_name, trade_date, profit_type, sale_amount, cost_amount, acq_date)
            """)
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_tx_year     ON transactions(year)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_tx_category ON transactions(category)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_tx_ptype    ON transactions(profit_type)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_tx_account  ON transactions(account_type)")
        }

        try migrator.migrate(writer)
    }
}
