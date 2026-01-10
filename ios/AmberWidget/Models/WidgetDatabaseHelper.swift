//
//  WidgetDatabaseHelper.swift
//  AmberWidget
//
//  直接操作 SQLite 数据库
//  通过 App Group 共享目录访问主 App 的数据库
//

import Foundation
import SQLite3

/// Widget 数据库助手
/// 直接读写 App Group 共享目录中的 SQLite 数据库
class WidgetDatabaseHelper {

    // MARK: - Constants

    /// App Group ID（必须与 Flutter 主 App 和 Xcode 配置一致）
    private static let appGroupID = "group.com.amberlist.amberList"

    /// 数据库文件名
    private static let dbFileName = "amber_list.db"

    // MARK: - Database Path

    /// 获取数据库文件路径
    /// 从 App Group 共享目录获取
    static func getDatabasePath() -> String? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            print("[WidgetDB] App Group container not found")
            return nil
        }
        return containerURL.appendingPathComponent(dbFileName).path
    }

    // MARK: - Database Connection

    /// 打开数据库连接
    private static func openDatabase() -> OpaquePointer? {
        guard let dbPath = getDatabasePath() else {
            return nil
        }

        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX

        if sqlite3_open_v2(dbPath, &db, flags, nil) == SQLITE_OK {
            // 设置 WAL 模式和超时
            sqlite3_exec(db, "PRAGMA journal_mode = WAL", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA busy_timeout = 5000", nil, nil, nil)
            print("[WidgetDB] Database opened: \(dbPath)")
            return db
        } else {
            print("[WidgetDB] Failed to open database: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
    }

    /// 关闭数据库连接
    private static func closeDatabase(_ db: OpaquePointer?) {
        if let db = db {
            sqlite3_close(db)
        }
    }

    // MARK: - Load Tasks

    /// 加载所有未完成的任务（用于 Widget 显示）
    /// 返回指定日期范围内的未完成、未删除的任务
    static func loadTasks() -> [WidgetTask] {
        guard let db = openDatabase() else {
            print("[WidgetDB] loadTasks: failed to open database")
            return []
        }
        defer { closeDatabase(db) }

        var tasks: [WidgetTask] = []

        // 先查一条数据看看 due_date 的格式
        let debugSql = "SELECT id, title, due_date FROM tasks WHERE due_date IS NOT NULL LIMIT 1"
        var debugStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, debugSql, -1, &debugStmt, nil) == SQLITE_OK {
            if sqlite3_step(debugStmt) == SQLITE_ROW {
                let debugId = String(cString: sqlite3_column_text(debugStmt, 0))
                let debugTitle = String(cString: sqlite3_column_text(debugStmt, 1))
                let debugDueDate = sqlite3_column_int64(debugStmt, 2)
                print("[WidgetDB] DEBUG: id=\(debugId), title=\(debugTitle), due_date=\(debugDueDate)")
                // 判断是秒还是毫秒：如果 > 10000000000 (约 2286年) 就是毫秒
                if debugDueDate > 10_000_000_000 {
                    print("[WidgetDB] DEBUG: due_date is in MILLISECONDS")
                } else {
                    print("[WidgetDB] DEBUG: due_date is in SECONDS")
                }
            }
        }
        sqlite3_finalize(debugStmt)

        // 简化查询：先不限制日期范围，看能否查到数据
        let sql = """
            SELECT id, title, is_completed, priority, due_date
            FROM tasks
            WHERE is_deleted = 0
              AND is_completed = 0
              AND due_date IS NOT NULL
            ORDER BY due_date ASC, priority DESC
            LIMIT 100
            """

        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {

            while sqlite3_step(statement) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(statement, 0))
                let title = String(cString: sqlite3_column_text(statement, 1))
                let isCompleted = sqlite3_column_int(statement, 2) != 0
                let priority = Int(sqlite3_column_int(statement, 3))
                let dueDateRaw = sqlite3_column_int64(statement, 4)

                // Drift 存的是秒级时间戳，不是毫秒！
                let dueDate = Date(timeIntervalSince1970: Double(dueDateRaw))
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let dueTime = dateFormatter.string(from: dueDate)

                // 格式化时间显示
                var dueTimeDisplay: String? = nil
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm"
                let timeStr = timeFormatter.string(from: dueDate)
                if timeStr != "00:00" {
                    dueTimeDisplay = timeStr
                }

                let task = WidgetTask(
                    id: id,
                    title: title,
                    isCompleted: isCompleted,
                    priority: priority,
                    dueDate: dueDateRaw,  // 秒级时间戳
                    dueTime: dueTime,
                    dueTimeDisplay: dueTimeDisplay
                )
                tasks.append(task)
            }
        } else {
            print("[WidgetDB] Query failed: \(String(cString: sqlite3_errmsg(db)))")
        }

        sqlite3_finalize(statement)
        print("[WidgetDB] Loaded \(tasks.count) tasks from database")
        return tasks
    }

    /// 加载未完成的任务
    static func loadIncompleteTasks() -> [WidgetTask] {
        return loadTasks().filter { !$0.isCompleted }
    }

    /// 加载今日任务（只显示截止日期等于今天的任务）
    ///
    /// 注意：已过期任务不会显示在 Widget 上。
    /// 自动顺延功能由 Flutter App 在启动时处理，不在 Widget 中执行。
    static func loadTodayTasks() -> [WidgetTask] {
        let allTasks = loadIncompleteTasks()
        print("[WidgetDB] loadTodayTasks: total incomplete tasks = \(allTasks.count)")

        // 获取今天的日期字符串 (yyyy-MM-dd)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date())

        let todayTasks = allTasks.filter { task in
            guard let dueTime = task.dueTime else {
                print("[WidgetDB] Task '\(task.title)' has no dueTime")
                return false
            }
            // 只显示截止日期 == 今天的任务
            let include = dueTime == todayStr
            print("[WidgetDB] Task '\(task.title)' dueTime=\(dueTime) today=\(todayStr) include=\(include)")
            return include
        }

        print("[WidgetDB] loadTodayTasks: filtered = \(todayTasks.count)")
        return todayTasks
    }

    // MARK: - Toggle Task

    /// 切换任务完成状态
    /// 直接更新 SQLite 数据库
    static func toggleTaskCompletion(taskId: String) -> Bool {
        guard let db = openDatabase() else {
            return false
        }
        defer { closeDatabase(db) }

        // 1. 先查询当前状态
        var currentStatus = false
        let selectSQL = "SELECT is_completed FROM tasks WHERE id = ?"
        var selectStatement: OpaquePointer?

        if sqlite3_prepare_v2(db, selectSQL, -1, &selectStatement, nil) == SQLITE_OK {
            // 使用 NSString 确保字符串正确传递给 SQLite
            let taskIdNS = taskId as NSString
            sqlite3_bind_text(selectStatement, 1, taskIdNS.utf8String, -1, nil)

            if sqlite3_step(selectStatement) == SQLITE_ROW {
                currentStatus = sqlite3_column_int(selectStatement, 0) != 0
            }
        }
        sqlite3_finalize(selectStatement)

        // 2. 更新为相反状态
        let newStatus = !currentStatus
        // 重要：Drift 存储的是秒级时间戳，不是毫秒！
        let nowSeconds = Int64(Date().timeIntervalSince1970)

        let updateSQL: String
        if newStatus {
            // 标记为完成
            updateSQL = """
                UPDATE tasks
                SET is_completed = 1,
                    is_in_progress = 0,
                    completed_at = ?,
                    updated_at = ?
                WHERE id = ?
                """
        } else {
            // 标记为未完成
            updateSQL = """
                UPDATE tasks
                SET is_completed = 0,
                    completed_at = NULL,
                    updated_at = ?
                WHERE id = ?
                """
        }

        var updateStatement: OpaquePointer?
        var success = false

        if sqlite3_prepare_v2(db, updateSQL, -1, &updateStatement, nil) == SQLITE_OK {
            // 使用 NSString 确保字符串正确传递给 SQLite
            let taskIdNS = taskId as NSString

            if newStatus {
                sqlite3_bind_int64(updateStatement, 1, nowSeconds)
                sqlite3_bind_int64(updateStatement, 2, nowSeconds)
                sqlite3_bind_text(updateStatement, 3, taskIdNS.utf8String, -1, nil)
            } else {
                sqlite3_bind_int64(updateStatement, 1, nowSeconds)
                sqlite3_bind_text(updateStatement, 2, taskIdNS.utf8String, -1, nil)
            }

            if sqlite3_step(updateStatement) == SQLITE_DONE {
                success = true
                print("[WidgetDB] Task \(taskId) toggled to completed=\(newStatus)")
            } else {
                print("[WidgetDB] Update failed: \(String(cString: sqlite3_errmsg(db)))")
            }
        }

        sqlite3_finalize(updateStatement)
        return success
    }

    // MARK: - Database Status

    /// 检查数据库是否存在
    static func databaseExists() -> Bool {
        guard let dbPath = getDatabasePath() else {
            print("[WidgetDB] databaseExists: path is nil")
            return false
        }
        let exists = FileManager.default.fileExists(atPath: dbPath)
        print("[WidgetDB] databaseExists: path=\(dbPath), exists=\(exists)")
        return exists
    }
}
