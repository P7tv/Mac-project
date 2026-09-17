import Foundation
import SQLite3
import NaturalLanguage

public final class RecallDatabase: @unchecked Sendable {
    private var db: OpaquePointer?
    private let lock = NSLock()
    public let databasePath: String

    public init(databasePath: String? = nil) {
        if let path = databasePath {
            self.databasePath = path
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("QuickRecall", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.databasePath = dir.appendingPathComponent("recall.sqlite3").path
        }

        openDatabase()
        createTables()
    }

    deinit {
        lock.withLock {
            if db != nil {
                sqlite3_close(db)
                db = nil
            }
        }
    }

    private func openDatabase() {
        lock.withLock {
            if sqlite3_open_v2(
                databasePath,
                &db,
                SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
                nil
            ) != SQLITE_OK {
                print("[QuickRecallDB] Failed to open database at \(databasePath)")
            }
        }
    }

    private func createTables() {
        lock.withLock {
            guard let db = db else { return }

            let sql = """
            CREATE TABLE IF NOT EXISTS records (
                id TEXT PRIMARY KEY,
                timestamp REAL,
                app_name TEXT,
                window_title TEXT,
                extracted_text TEXT,
                thumbnail_path TEXT
            );

            CREATE VIRTUAL TABLE IF NOT EXISTS records_fts USING fts5(
                id UNINDEXED,
                extracted_text,
                app_name,
                window_title
            );
            """

            var err: UnsafeMutablePointer<CChar>?
            if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
                if let err = err {
                    print("[QuickRecallDB] Table creation error: \(String(cString: err))")
                    sqlite3_free(err)
                }
            }
        }
    }

    public func insert(record: RecallRecord) {
        lock.withLock {
            guard let db = db else { return }

            // 1. Insert into main records table
            let insertSql = "INSERT OR REPLACE INTO records (id, timestamp, app_name, window_title, extracted_text, thumbnail_path) VALUES (?, ?, ?, ?, ?, ?);"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, insertSql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (record.id as NSString).utf8String, -1, nil)
                sqlite3_bind_double(stmt, 2, record.timestamp.timeIntervalSince1970)
                sqlite3_bind_text(stmt, 3, (record.appName as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 4, (record.windowTitle as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 5, (record.extractedText as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 6, (record.thumbnailPath as NSString).utf8String, -1, nil)

                if sqlite3_step(stmt) != SQLITE_DONE {
                    print("[QuickRecallDB] Insert records failed: \(String(cString: sqlite3_errmsg(db)))")
                }
                sqlite3_finalize(stmt)
            }

            // 2. Insert into FTS5 virtual table with word segmentation (supports Thai & English)
            let searchIndexText = tokenizeWords(record.extractedText)
            let ftsSql = "INSERT INTO records_fts (id, extracted_text, app_name, window_title) VALUES (?, ?, ?, ?);"
            var ftsStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, ftsSql, -1, &ftsStmt, nil) == SQLITE_OK {
                sqlite3_bind_text(ftsStmt, 1, (record.id as NSString).utf8String, -1, nil)
                sqlite3_bind_text(ftsStmt, 2, (searchIndexText as NSString).utf8String, -1, nil)
                sqlite3_bind_text(ftsStmt, 3, (record.appName as NSString).utf8String, -1, nil)
                sqlite3_bind_text(ftsStmt, 4, (record.windowTitle as NSString).utf8String, -1, nil)

                if sqlite3_step(ftsStmt) != SQLITE_DONE {
                    print("[QuickRecallDB] Insert FTS failed: \(String(cString: sqlite3_errmsg(db)))")
                }
                sqlite3_finalize(ftsStmt)
            }
        }
    }

    public func search(query: String, limit: Int = 30) -> [RecallRecord] {
        lock.withLock {
            guard let db = db else { return [] }
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return recentRecords(limit: limit)
            }

            // Clean query to avoid syntax errors with special chars in FTS5
            let sanitized = sanitizeFTSQuery(trimmed)
            if sanitized.isEmpty {
                return recentRecords(limit: limit)
            }

            let searchSql = """
            SELECT r.id, r.timestamp, r.app_name, r.window_title, r.extracted_text, r.thumbnail_path,
                   snippet(records_fts, 1, '<b>', '</b>', '...', 25) AS snippet
            FROM records_fts
            JOIN records r ON records_fts.id = r.id
            WHERE records_fts MATCH ?
            ORDER BY rank
            LIMIT ?;
            """

            var stmt: OpaquePointer?
            var results: [RecallRecord] = []

            if sqlite3_prepare_v2(db, searchSql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (sanitized as NSString).utf8String, -1, nil)
                sqlite3_bind_int(stmt, 2, Int32(limit))

                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let record = parseRecord(from: stmt) {
                        results.append(record)
                    }
                }
                sqlite3_finalize(stmt)
            } else {
                print("[QuickRecallDB] Search failed: \(String(cString: sqlite3_errmsg(db)))")
            }

            return results
        }
    }

    public func recentRecords(limit: Int = 30) -> [RecallRecord] {
        lock.withLock {
            guard let db = db else { return [] }

            let sql = "SELECT id, timestamp, app_name, window_title, extracted_text, thumbnail_path, '' FROM records ORDER BY timestamp DESC LIMIT ?;"
            var stmt: OpaquePointer?
            var results: [RecallRecord] = []

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(limit))

                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let record = parseRecord(from: stmt) {
                        results.append(record)
                    }
                }
                sqlite3_finalize(stmt)
            }

            return results
        }
    }

    public func count() -> Int {
        lock.withLock {
            guard let db = db else { return 0 }
            let sql = "SELECT COUNT(*) FROM records;"
            var stmt: OpaquePointer?
            var count = 0

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_ROW {
                    count = Int(sqlite3_column_int(stmt, 0))
                }
                sqlite3_finalize(stmt)
            }

            return count
        }
    }

    public func prune(olderThan days: Int) {
        lock.withLock {
            guard let db = db else { return }
            let cutoff = Date().timeIntervalSince1970 - Double(days * 86400)

            let pruneFtsSql = "DELETE FROM records_fts WHERE id IN (SELECT id FROM records WHERE timestamp < ?);"
            var ftsStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, pruneFtsSql, -1, &ftsStmt, nil) == SQLITE_OK {
                sqlite3_bind_double(ftsStmt, 1, cutoff)
                sqlite3_step(ftsStmt)
                sqlite3_finalize(ftsStmt)
            }

            let pruneSql = "DELETE FROM records WHERE timestamp < ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, pruneSql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_double(stmt, 1, cutoff)
                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }
        }
    }

    public func clearAll() {
        lock.withLock {
            guard let db = db else { return }
            sqlite3_exec(db, "DELETE FROM records_fts; DELETE FROM records; VACUUM;", nil, nil, nil)
        }
    }

    // MARK: - Helpers
    private func parseRecord(from stmt: OpaquePointer?) -> RecallRecord? {
        guard let stmt = stmt else { return nil }

        guard let idCol = sqlite3_column_text(stmt, 0) else { return nil }
        let id = String(cString: idCol)

        let timestampSec = sqlite3_column_double(stmt, 1)
        let timestamp = Date(timeIntervalSince1970: timestampSec)

        let appName = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? "Unknown"
        let windowTitle = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
        let extractedText = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? ""
        let thumbnailPath = sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? ""
        let snippet = sqlite3_column_text(stmt, 6).map { String(cString: $0) }

        return RecallRecord(
            id: id,
            timestamp: timestamp,
            appName: appName,
            windowTitle: windowTitle,
            extractedText: extractedText,
            thumbnailPath: thumbnailPath,
            matchSnippet: snippet?.isEmpty == true ? nil : snippet
        )
    }

    private func sanitizeFTSQuery(_ query: String) -> String {
        let tokenized = tokenizeWords(query)
        let words = tokenized.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let tokens = words.map { word -> String in
            let escaped = word.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\"*"
        }
        return tokens.joined(separator: " ")
    }

    private func tokenizeWords(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var tokens: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            tokens.append(String(text[range]))
            return true
        }
        return tokens.isEmpty ? text : tokens.joined(separator: " ")
    }
}
