package com.example.amber_list.widget

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import java.io.File

/**
 * Widget Database Helper
 *
 * Provides direct SQLite access for widget task operations.
 * This allows toggling task completion without launching the Flutter app.
 *
 * Database path: {app_documents}/amber_list.db
 * Table: tasks
 * - id (TEXT PRIMARY KEY)
 * - title (TEXT)
 * - is_completed (INTEGER 0/1)
 * - completed_at (INTEGER nullable, timestamp)
 * - updated_at (INTEGER, timestamp)
 */
object WidgetDatabaseHelper {

    private const val TAG = "WidgetDbHelper"
    private const val DB_NAME = "amber_list.db"

    /**
     * Task data class for widget display
     */
    data class WidgetTask(
        val id: String,
        val title: String,
        val isCompleted: Boolean,
        val priority: Int,
        val dueTime: String? = null
    )

    /**
     * Load all tasks from SQLite database
     * Used by Widget to display task list
     *
     * @param context Application context
     * @return List of tasks ordered by due date
     */
    fun loadAllTasks(context: Context): List<WidgetTask> {
        return try {
            val dbPath = getDatabasePath(context)
            val dbFile = File(dbPath)

            if (!dbFile.exists()) {
                Log.e(TAG, "Database file not found: $dbPath")
                return emptyList()
            }

            val database = SQLiteDatabase.openDatabase(
                dbPath,
                null,
                SQLiteDatabase.OPEN_READONLY
            )

            // Query all non-deleted tasks with due date
            val cursor = database.rawQuery(
                """
                SELECT id, title, is_completed, priority, due_date
                FROM tasks
                WHERE is_deleted = 0
                  AND due_date IS NOT NULL
                ORDER BY due_date ASC, priority DESC, created_at ASC
                LIMIT 100
                """.trimIndent(),
                null
            )

            val tasks = mutableListOf<WidgetTask>()
            while (cursor.moveToNext()) {
                val id = cursor.getString(0)
                val title = cursor.getString(1)
                val isCompleted = cursor.getInt(2) == 1
                val priority = cursor.getInt(3)
                // IMPORTANT: Drift stores timestamps in SECONDS
                val dueTimestampSeconds = cursor.getLong(4)
                var dueTime: String? = null
                if (dueTimestampSeconds > 0) {
                    val date = java.util.Date(dueTimestampSeconds * 1000)
                    val formatter = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.getDefault())
                    dueTime = formatter.format(date)
                }
                // Debug: log each task with due date details
                Log.d(TAG, "Task: '$title', completed=$isCompleted, dueTimestamp=$dueTimestampSeconds, dueTime=$dueTime")
                tasks.add(WidgetTask(id, title, isCompleted, priority, dueTime))
            }
            cursor.close()
            database.close()

            Log.d(TAG, "Loaded ${tasks.size} tasks from SQLite (dbPath: $dbPath)")
            tasks
        } catch (e: Exception) {
            Log.e(TAG, "Error loading tasks from SQLite", e)
            emptyList()
        }
    }

    /**
     * Load today's tasks from SQLite database
     * Returns incomplete tasks with dueDate == today (only today's tasks)
     *
     * Note: Overdue tasks are NOT shown. The auto-postpone feature is handled
     * by the Flutter app on startup, not by the widget.
     *
     * @param context Application context
     * @return List of today's incomplete tasks
     */
    fun loadTodayTasks(context: Context): List<WidgetTask> {
        val allTasks = loadAllTasks(context)
        val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.getDefault())
            .format(java.util.Date())

        Log.d(TAG, "loadTodayTasks: today=$today, allTasks=${allTasks.size}")

        val result = allTasks.filter { task ->
            // Must be incomplete
            if (task.isCompleted) {
                Log.d(TAG, "  Skipping '${task.title}': completed")
                return@filter false
            }
            // Must have due date
            val dueTime = task.dueTime
            if (dueTime == null) {
                Log.d(TAG, "  Skipping '${task.title}': no due date")
                return@filter false
            }
            // Due date == today (only today's tasks, not overdue)
            val include = dueTime == today
            Log.d(TAG, "  Task '${task.title}': dueTime=$dueTime, include=$include (compare: $dueTime == $today)")
            include
        }

        Log.d(TAG, "loadTodayTasks: returning ${result.size} tasks")
        return result
    }

    /**
     * Check if database exists
     */
    fun databaseExists(context: Context): Boolean {
        val dbPath = getDatabasePath(context)
        return File(dbPath).exists()
    }

    /**
     * Toggle task completion status in SQLite database
     *
     * @param context Application context
     * @param taskId Task ID to toggle
     * @return true if successful, false otherwise
     */
    fun toggleTaskCompletion(context: Context, taskId: String): Boolean {
        return try {
            val dbPath = getDatabasePath(context)
            val dbFile = File(dbPath)

            if (!dbFile.exists()) {
                Log.e(TAG, "Database file not found: $dbPath")
                return false
            }

            val database = SQLiteDatabase.openDatabase(
                dbPath,
                null,
                SQLiteDatabase.OPEN_READWRITE
            )

            // First, read current completion status
            val cursor = database.rawQuery(
                "SELECT is_completed FROM tasks WHERE id = ?",
                arrayOf(taskId)
            )

            var currentStatus = false
            if (cursor.moveToFirst()) {
                currentStatus = cursor.getInt(0) == 1
            }
            cursor.close()

            // Toggle the status
            val newStatus = !currentStatus
            // IMPORTANT: Drift stores timestamps in SECONDS, not milliseconds!
            val nowSeconds = System.currentTimeMillis() / 1000

            // Update the task
            val completedAt = if (newStatus) nowSeconds else null
            database.execSQL(
                """
                UPDATE tasks
                SET is_completed = ?,
                    completed_at = ?,
                    updated_at = ?
                WHERE id = ?
                """.trimIndent(),
                arrayOf(
                    if (newStatus) 1 else 0,
                    completedAt,
                    nowSeconds,
                    taskId
                )
            )

            database.close()

            Log.d(TAG, "Task $taskId toggled to completed=$newStatus")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error toggling task completion", e)
            false
        }
    }

    /**
     * Get database file path
     *
     * Flutter drift database is stored in app documents directory.
     * On Android: /data/data/{package}/app_flutter/amber_list.db
     */
    private fun getDatabasePath(context: Context): String {
        // Flutter's getApplicationDocumentsDirectory() maps to app_flutter subfolder on Android
        val appFlutterDir = File(context.filesDir.parentFile, "app_flutter")
        return File(appFlutterDir, DB_NAME).absolutePath
    }
}
