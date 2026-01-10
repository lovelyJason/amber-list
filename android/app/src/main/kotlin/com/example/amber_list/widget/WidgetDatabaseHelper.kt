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
                tasks.add(WidgetTask(id, title, isCompleted, priority, dueTime))
            }
            cursor.close()
            database.close()

            tasks
        } catch (e: Exception) {
            Log.e(TAG, "Error loading tasks from SQLite", e)
            emptyList()
        }
    }

    /**
     * Load today's tasks from SQLite database
     * Returns incomplete tasks with dueDate == today OR overdue tasks
     *
     * Note: This method now includes overdue tasks since the Widget also
     * performs auto-postpone on update. After auto-postpone, overdue tasks
     * become today's tasks.
     *
     * @param context Application context
     * @return List of today's and overdue incomplete tasks
     */
    fun loadTodayTasks(context: Context): List<WidgetTask> {
        val allTasks = loadAllTasks(context)
        val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.getDefault())
            .format(java.util.Date())


        return allTasks.filter { task ->
            // Must be incomplete and have due date
            if (task.isCompleted) return@filter false
            val dueTime = task.dueTime ?: return@filter false
            // Due date == today OR overdue (dueTime <= today)
            dueTime <= today
        }
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
            // Note: When marking as complete, also reset is_in_progress to 0
            // to maintain consistency with iOS widget behavior
            val completedAt = if (newStatus) nowSeconds else null
            if (newStatus) {
                database.execSQL(
                    """
                    UPDATE tasks
                    SET is_completed = 1,
                        is_in_progress = 0,
                        completed_at = ?,
                        updated_at = ?
                    WHERE id = ?
                    """.trimIndent(),
                    arrayOf(
                        completedAt,
                        nowSeconds,
                        taskId
                    )
                )
            } else {
                database.execSQL(
                    """
                    UPDATE tasks
                    SET is_completed = 0,
                        completed_at = NULL,
                        updated_at = ?
                    WHERE id = ?
                    """.trimIndent(),
                    arrayOf(
                        nowSeconds,
                        taskId
                    )
                )
            }

            database.close()

            Log.d(TAG, "Task $taskId toggled to completed=$newStatus")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error toggling task completion", e)
            false
        }
    }

    /**
     * Perform auto-postpone for overdue tasks
     *
     * This method is called when the Widget is updated (onUpdate).
     * It checks if auto-postpone has been done today, and if not,
     * postpones all overdue tasks with auto_postpone=1 to today.
     *
     * Conditions for postponing a task:
     * - is_deleted = 0 (not deleted)
     * - is_completed = 0 (not completed)
     * - auto_postpone = 1 (task allows auto-postpone)
     * - due_date < today (overdue)
     *
     * @param context Application context
     * @return Number of tasks postponed, or 0 if skipped/failed
     */
    fun performAutoPostpone(context: Context): Int {
        try {
            // Step 1: Check if auto-postpone is enabled globally
            if (!WidgetSettingsHelper.isAutoPostponeEnabled(context)) return 0

            // Step 2: Check if already done today
            if (WidgetSettingsHelper.hasCheckedToday(context)) return 0

            // Step 3: Open database
            val dbPath = getDatabasePath(context)
            val dbFile = File(dbPath)

            if (!dbFile.exists()) return 0

            val database = SQLiteDatabase.openDatabase(
                dbPath,
                null,
                SQLiteDatabase.OPEN_READWRITE
            )

            // Step 4: Calculate today's timestamp (start of day in seconds)
            // Drift stores due_date as Unix timestamp in seconds (UTC)
            val calendar = java.util.Calendar.getInstance()
            calendar.set(java.util.Calendar.HOUR_OF_DAY, 0)
            calendar.set(java.util.Calendar.MINUTE, 0)
            calendar.set(java.util.Calendar.SECOND, 0)
            calendar.set(java.util.Calendar.MILLISECOND, 0)
            val todayStartSeconds = calendar.timeInMillis / 1000
            val nowSeconds = System.currentTimeMillis() / 1000


            // Step 5: Count overdue tasks first (for logging)
            val countCursor = database.rawQuery(
                """
                SELECT COUNT(*) FROM tasks
                WHERE is_deleted = 0
                  AND is_completed = 0
                  AND auto_postpone = 1
                  AND due_date IS NOT NULL
                  AND due_date < ?
                """.trimIndent(),
                arrayOf(todayStartSeconds.toString())
            )
            var overdueCount = 0
            if (countCursor.moveToFirst()) {
                overdueCount = countCursor.getInt(0)
            }
            countCursor.close()

            if (overdueCount == 0) {
                database.close()
                // Still mark as checked today (no tasks to postpone)
                WidgetSettingsHelper.setCheckedToday(context)
                return 0
            }

            // Step 6: Update overdue tasks to today
            database.execSQL(
                """
                UPDATE tasks
                SET due_date = ?,
                    updated_at = ?
                WHERE is_deleted = 0
                  AND is_completed = 0
                  AND auto_postpone = 1
                  AND due_date IS NOT NULL
                  AND due_date < ?
                """.trimIndent(),
                arrayOf(
                    todayStartSeconds,
                    nowSeconds,
                    todayStartSeconds
                )
            )

            database.close()

            // Step 7: Mark as checked today
            WidgetSettingsHelper.setCheckedToday(context)

            // Only log when tasks are actually postponed
            if (overdueCount > 0) {
                Log.i(TAG, "Auto-postponed $overdueCount tasks to today")
            }
            return overdueCount
        } catch (e: Exception) {
            Log.e(TAG, "performAutoPostpone error", e)
            return 0
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
