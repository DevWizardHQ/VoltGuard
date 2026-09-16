import Foundation

enum Migrations {
    static let all: [(version: Int, sql: String)] = [
        (
            1,
            """
            CREATE TABLE IF NOT EXISTS samples (
                id               INTEGER PRIMARY KEY,
                ts               INTEGER NOT NULL,
                percentage       INTEGER NOT NULL,
                charging_state   INTEGER NOT NULL,
                power_source     INTEGER NOT NULL,
                monitoring_state INTEGER NOT NULL,
                cycle_count      INTEGER,
                max_capacity_pct INTEGER
            );
            CREATE INDEX IF NOT EXISTS idx_samples_ts ON samples(ts);

            CREATE TABLE IF NOT EXISTS charging_sessions (
                id              INTEGER PRIMARY KEY,
                started_at      INTEGER NOT NULL,
                ended_at        INTEGER,
                start_pct       INTEGER NOT NULL,
                end_pct         INTEGER,
                peak_pct        INTEGER NOT NULL,
                reached_full_at INTEGER
            );
            CREATE INDEX IF NOT EXISTS idx_sessions_started ON charging_sessions(started_at);

            CREATE TABLE IF NOT EXISTS alert_events (
                id           INTEGER PRIMARY KEY,
                ts           INTEGER NOT NULL,
                rule_id      TEXT NOT NULL,
                rule_name    TEXT NOT NULL,
                direction    INTEGER NOT NULL,
                threshold    INTEGER NOT NULL,
                percentage   INTEGER NOT NULL,
                power_source INTEGER NOT NULL,
                channels     TEXT NOT NULL,
                outcome      INTEGER NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_alerts_ts ON alert_events(ts);
            """
        )
    ]

    static func apply(to database: SQLiteDatabase) throws {
        for migration in all where migration.version > database.userVersion {
            try database.transaction {
                try database.execute(migration.sql)
            }
            database.userVersion = migration.version
        }
    }
}
