import Foundation
import SQLite3

private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public enum SQLiteError: Error, CustomStringConvertible {
    case open(String)
    case prepare(String)
    case step(String)

    public var description: String {
        switch self {
        case let .open(message): "sqlite open failed: \(message)"
        case let .prepare(message): "sqlite prepare failed: \(message)"
        case let .step(message): "sqlite step failed: \(message)"
        }
    }
}

final class SQLiteDatabase {
    private var handle: OpaquePointer?

    init(path: String) throws {
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(path, &handle, flags, nil) == SQLITE_OK, let handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close_v2(handle)
            throw SQLiteError.open(message)
        }
        self.handle = handle
        try execute("PRAGMA journal_mode = WAL;")
        try execute("PRAGMA synchronous = NORMAL;")
        try execute("PRAGMA foreign_keys = ON;")
        try execute("PRAGMA auto_vacuum = INCREMENTAL;")
    }

    deinit {
        sqlite3_close_v2(handle)
    }

    private var errorMessage: String {
        handle.map { String(cString: sqlite3_errmsg($0)) } ?? "no database"
    }

    func execute(_ sql: String) throws {
        guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else {
            throw SQLiteError.step(errorMessage)
        }
    }

    func transaction<T>(_ body: () throws -> T) throws -> T {
        try execute("BEGIN IMMEDIATE;")
        do {
            let result = try body()
            try execute("COMMIT;")
            return result
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    @discardableResult
    func run(_ sql: String, _ parameters: [SQLiteValue] = []) throws -> Int64 {
        let statement = try prepare(sql, parameters)
        defer { sqlite3_finalize(statement) }
        let code = sqlite3_step(statement)
        guard code == SQLITE_DONE || code == SQLITE_ROW else {
            throw SQLiteError.step(errorMessage)
        }
        return sqlite3_last_insert_rowid(handle)
    }

    func query<T>(_ sql: String, _ parameters: [SQLiteValue] = [], row: (SQLiteRow) -> T) throws -> [T] {
        let statement = try prepare(sql, parameters)
        defer { sqlite3_finalize(statement) }
        var results: [T] = []
        while true {
            let code = sqlite3_step(statement)
            if code == SQLITE_ROW {
                results.append(row(SQLiteRow(statement: statement)))
            } else if code == SQLITE_DONE {
                break
            } else {
                throw SQLiteError.step(errorMessage)
            }
        }
        return results
    }

    /// Steps a query lazily so exports never materialize the whole table.
    func forEachRow(_ sql: String, _ parameters: [SQLiteValue] = [], body: (SQLiteRow) throws -> Void) throws
    {
        let statement = try prepare(sql, parameters)
        defer { sqlite3_finalize(statement) }
        while true {
            let code = sqlite3_step(statement)
            if code == SQLITE_ROW {
                try body(SQLiteRow(statement: statement))
            } else if code == SQLITE_DONE {
                break
            } else {
                throw SQLiteError.step(errorMessage)
            }
        }
    }

    var userVersion: Int {
        get { (try? query("PRAGMA user_version;") { $0.int(0) })?.first ?? 0 }
        set { try? execute("PRAGMA user_version = \(newValue);") }
    }

    private func prepare(_ sql: String, _ parameters: [SQLiteValue]) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepare("\(errorMessage) — \(sql)")
        }
        for (index, value) in parameters.enumerated() {
            value.bind(to: statement, at: Int32(index + 1))
        }
        return statement
    }
}

enum SQLiteValue {
    case integer(Int64)
    case double(Double)
    case text(String)
    case null

    static func int(_ value: Int) -> SQLiteValue { .integer(Int64(value)) }
    static func optionalInt(_ value: Int?) -> SQLiteValue { value.map { .integer(Int64($0)) } ?? .null }
    static func date(_ value: Date) -> SQLiteValue { .integer(Int64(value.timeIntervalSince1970)) }
    static func optionalDate(_ value: Date?) -> SQLiteValue { value.map { .date($0) } ?? .null }

    func bind(to statement: OpaquePointer?, at index: Int32) {
        switch self {
        case let .integer(value): sqlite3_bind_int64(statement, index, value)
        case let .double(value): sqlite3_bind_double(statement, index, value)
        case let .text(value): sqlite3_bind_text(statement, index, value, -1, transient)
        case .null: sqlite3_bind_null(statement, index)
        }
    }
}

struct SQLiteRow {
    let statement: OpaquePointer?

    func int(_ index: Int32) -> Int { Int(sqlite3_column_int64(statement, index)) }
    func int64(_ index: Int32) -> Int64 { sqlite3_column_int64(statement, index) }
    func double(_ index: Int32) -> Double { sqlite3_column_double(statement, index) }
    func date(_ index: Int32) -> Date {
        Date(timeIntervalSince1970: Double(sqlite3_column_int64(statement, index)))
    }

    func isNull(_ index: Int32) -> Bool { sqlite3_column_type(statement, index) == SQLITE_NULL }
    func optionalInt(_ index: Int32) -> Int? { isNull(index) ? nil : int(index) }
    func optionalDate(_ index: Int32) -> Date? { isNull(index) ? nil : date(index) }

    func text(_ index: Int32) -> String {
        guard let pointer = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: pointer)
    }
}
