package com.example.amber_list.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RectF
import android.net.Uri
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import com.example.amber_list.R

/**
 * Amber List Home Screen Widget Provider
 *
 * Handles widget lifecycle and rendering for all three sizes:
 * - Small (2x2): Shows app logo + task count
 * - Medium (4x2): Shows up to 3 tasks
 * - Large (4x4): Shows up to 6 tasks
 *
 * Data Flow:
 * Flutter -> HomeWidgetPlugin -> SharedPreferences -> This Provider -> RemoteViews
 *
 * Interaction:
 * Widget Click -> PendingIntent -> BroadcastReceiver -> Flutter App
 */
open class AmberWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "AmberWidget"

        // SharedPreferences key (must match Flutter HomeWidgetService)
        private const val KEY_WIDGET_TASKS = "widget_tasks"
        private const val KEY_SMALL_WIDGET_SKIN = "widget_small_skin"
        private const val KEY_TAP_TEXT_TO_COMPLETE = "widget_tap_text_to_complete"

        // Action for task toggle click (opens app - legacy)
        const val ACTION_TOGGLE_TASK = "com.example.amber_list.TOGGLE_TASK"
        const val EXTRA_TASK_ID = "task_id"

        // Action for direct task toggle (no app launch, direct SQLite)
        const val ACTION_TOGGLE_TASK_DIRECT = "com.example.amber_list.TOGGLE_TASK_DIRECT"

        // Action to open app
        const val ACTION_OPEN_APP = "com.example.amber_list.OPEN_APP"

        // Action for next page in small widget
        const val ACTION_NEXT_PAGE = "com.example.amber_list.NEXT_PAGE"

        // Action for next page in medium widget
        const val ACTION_NEXT_PAGE_MEDIUM = "com.example.amber_list.NEXT_PAGE_MEDIUM"

        // Actions for large widget calendar navigation
        const val ACTION_PREV_MONTH = "com.example.amber_list.PREV_MONTH"
        const val ACTION_NEXT_MONTH = "com.example.amber_list.NEXT_MONTH"
        const val ACTION_TODAY = "com.example.amber_list.GO_TODAY"
        const val ACTION_OPEN_DAY = "com.example.amber_list.OPEN_DAY"
        const val EXTRA_DAY_DATE = "day_date"

        // Amber gold color
        private const val AMBER_PRIMARY = 0xFFF5A623.toInt()
        private const val AMBER_PRIMARY_DARK = 0xFFD4891C.toInt()

        // Max tasks to show in small widget (uses StackView for rotation)
        private const val SMALL_WIDGET_MAX_TASKS = 6

    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // Perform auto-postpone before updating widgets
        // This ensures overdue tasks are moved to today on each widget refresh
        // Uses lastAutoPostponeDate to avoid repeated execution on the same day
        WidgetDatabaseHelper.performAutoPostpone(context)

        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        when (intent.action) {
            ACTION_TOGGLE_TASK -> {
                val taskId = intent.getStringExtra(EXTRA_TASK_ID)

                if (taskId != null) {
                    // Launch app with deep link to toggle task
                    val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    launchIntent?.apply {
                        data = Uri.parse("amberlist://widget/toggle_task?id=$taskId")
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                    context.startActivity(launchIntent)
                }
            }
            ACTION_TOGGLE_TASK_DIRECT -> {
                val taskId = intent.getStringExtra(EXTRA_TASK_ID)

                if (taskId != null) {
                    // Toggle task directly in SQLite database (no app launch)
                    val success = WidgetDatabaseHelper.toggleTaskCompletion(context, taskId)

                    if (success) {
                        // Refresh all widgets to reflect the change
                        refreshAllWidgets(context)
                    } else {
                        // Fallback: launch app if direct toggle fails
                        Log.w(TAG, "Direct toggle failed, falling back to app launch")
                        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                        launchIntent?.apply {
                            data = Uri.parse("amberlist://widget/toggle_task?id=$taskId")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        }
                        context.startActivity(launchIntent)
                    }
                }
            }
            ACTION_OPEN_APP -> {
                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                launchIntent?.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                context.startActivity(launchIntent)
            }
            ACTION_NEXT_PAGE -> {
                // Get current page and total pages from prefs
                val prefs = context.getSharedPreferences("amber_widget_prefs", Context.MODE_PRIVATE)
                val tasks = loadTasks(context)
                val todayTasks = filterTodayTasks(tasks)
                val totalTasks = todayTasks.size
                val tasksPerPage = 5
                val totalPages = if (totalTasks == 0) 1 else (totalTasks + tasksPerPage - 1) / tasksPerPage

                var currentPage = prefs.getInt("small_widget_page", 0)
                // Move to next page, loop back to first page after last page
                currentPage = (currentPage + 1) % totalPages
                prefs.edit().putInt("small_widget_page", currentPage).apply()

                // Refresh all widgets
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val widgetIds = appWidgetManager.getAppWidgetIds(
                    android.content.ComponentName(context, AmberWidgetProvider::class.java)
                )
                for (widgetId in widgetIds) {
                    updateAppWidget(context, appWidgetManager, widgetId)
                }
            }
            ACTION_NEXT_PAGE_MEDIUM -> {
                // Get current page and total pages from prefs
                val prefs = context.getSharedPreferences("amber_widget_prefs", Context.MODE_PRIVATE)
                val tasks = loadTasks(context)
                val todayTasks = filterTodayTasks(tasks)
                val totalTasks = todayTasks.size
                val tasksPerPage = 5
                val totalPages = if (totalTasks == 0) 1 else (totalTasks + tasksPerPage - 1) / tasksPerPage

                var currentPage = prefs.getInt("medium_widget_page", 0)
                // Move to next page, loop back to first page after last page
                currentPage = (currentPage + 1) % totalPages
                prefs.edit().putInt("medium_widget_page", currentPage).apply()

                // Refresh medium widgets
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val widgetIds = appWidgetManager.getAppWidgetIds(
                    android.content.ComponentName(context, AmberWidgetMediumProvider::class.java)
                )
                for (widgetId in widgetIds) {
                    updateAppWidget(context, appWidgetManager, widgetId)
                }
            }
            ACTION_PREV_MONTH -> {
                val prefs = context.getSharedPreferences("amber_widget_prefs", Context.MODE_PRIVATE)
                var monthOffset = prefs.getInt("large_widget_month_offset", 0)
                monthOffset--
                prefs.edit().putInt("large_widget_month_offset", monthOffset).apply()
                refreshLargeWidgets(context)
            }
            ACTION_NEXT_MONTH -> {
                val prefs = context.getSharedPreferences("amber_widget_prefs", Context.MODE_PRIVATE)
                var monthOffset = prefs.getInt("large_widget_month_offset", 0)
                monthOffset++
                prefs.edit().putInt("large_widget_month_offset", monthOffset).apply()
                refreshLargeWidgets(context)
            }
            ACTION_TODAY -> {
                val prefs = context.getSharedPreferences("amber_widget_prefs", Context.MODE_PRIVATE)
                prefs.edit().putInt("large_widget_month_offset", 0).apply()
                refreshLargeWidgets(context)
            }
            ACTION_OPEN_DAY -> {
                val dateStr = intent.getStringExtra(EXTRA_DAY_DATE)
                if (dateStr != null) {
                    // Launch app with deep link to calendar day view
                    val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    launchIntent?.apply {
                        data = Uri.parse("amberlist://widget/calendar?date=$dateStr")
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                    context.startActivity(launchIntent)
                }
            }
        }
    }

    /**
     * Refresh all large widgets
     */
    private fun refreshLargeWidgets(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val widgetIds = appWidgetManager.getAppWidgetIds(
            android.content.ComponentName(context, AmberWidgetLargeProvider::class.java)
        )
        for (widgetId in widgetIds) {
            updateAppWidget(context, appWidgetManager, widgetId)
        }
    }

    /**
     * Refresh all widget types (Small, Medium, Large)
     * Used after direct task toggle to update all widget displays
     */
    private fun refreshAllWidgets(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context)

        // Refresh Small widgets
        val smallIds = appWidgetManager.getAppWidgetIds(
            android.content.ComponentName(context, AmberWidgetProvider::class.java)
        )
        for (widgetId in smallIds) {
            updateAppWidget(context, appWidgetManager, widgetId)
        }

        // Refresh Medium widgets
        val mediumIds = appWidgetManager.getAppWidgetIds(
            android.content.ComponentName(context, AmberWidgetMediumProvider::class.java)
        )
        for (widgetId in mediumIds) {
            updateAppWidget(context, appWidgetManager, widgetId)
        }

        // Refresh Large widgets
        val largeIds = appWidgetManager.getAppWidgetIds(
            android.content.ComponentName(context, AmberWidgetLargeProvider::class.java)
        )
        for (widgetId in largeIds) {
            updateAppWidget(context, appWidgetManager, widgetId)
        }

    }

    override fun onEnabled(context: Context) {
        // Widget enabled
    }

    override fun onDisabled(context: Context) {
        // Widget disabled
    }

    /**
     * Called when widget is resized by dragging
     * This is crucial for contrast skins - we need to regenerate the rounded corner bitmap
     * at the new size to prevent corner deformation
     */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        // Re-render widget with new size - this will regenerate the bitmap with correct dimensions
        updateAppWidget(context, appWidgetManager, appWidgetId)
    }

    /**
     * Update a single widget instance
     * Subclasses can override getWidgetSize() to force a specific size
     */
    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {

        // Load tasks from SharedPreferences
        val tasks = loadTasks(context)

        // Get actual widget size from AppWidgetManager (for dynamic resizing support)
        // Note: MIN values represent the current size when widget is resized
        // We add extra padding to ensure the bitmap covers the full widget area
        val widgetOptions = appWidgetManager.getAppWidgetOptions(appWidgetId)
        val density = context.resources.displayMetrics.density
        val minWidthDp = widgetOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        val minHeightDp = widgetOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        val maxWidthDp = widgetOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, minWidthDp)
        val maxHeightDp = widgetOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, minHeightDp)

        // Use max of min/max to ensure we cover the full widget area
        // This handles cases where widget is expanded beyond minimum size
        val widthDp = maxOf(minWidthDp, maxWidthDp)
        val heightDp = maxOf(minHeightDp, maxHeightDp)
        val widthPx = (widthDp * density).toInt()
        val heightPx = (heightDp * density).toInt()

        Log.d(TAG, "Widget size: min=${minWidthDp}x${minHeightDp}dp, max=${maxWidthDp}x${maxHeightDp}dp, using=${widthDp}x${heightDp}dp = ${widthPx}x${heightPx}px")

        // Create appropriate RemoteViews based on widget size
        val views = when (getWidgetSize()) {
            WidgetSize.SMALL -> createSmallWidget(context, tasks, widthPx, heightPx)
            WidgetSize.MEDIUM -> createMediumWidget(context, tasks, widthPx, heightPx)
            WidgetSize.LARGE -> createLargeWidget(context, tasks, widthPx, heightPx)
        }

        // Update the widget
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    /**
     * Get the widget size for this provider
     * Subclasses override this to return their specific size
     */
    protected open fun getWidgetSize(): WidgetSize = WidgetSize.SMALL

    /**
     * Load tasks directly from SQLite database
     * Same approach as iOS - no SharedPreferences middle layer
     */
    private fun loadTasks(context: Context): List<WidgetTask> {
        val dbTasks = WidgetDatabaseHelper.loadAllTasks(context)
        return dbTasks.map { task ->
            WidgetTask(
                id = task.id,
                title = task.title,
                isCompleted = task.isCompleted,
                priority = task.priority,
                dueTime = task.dueTime
            )
        }
    }

    /**
     * Load today's tasks directly from SQLite database
     * Returns incomplete tasks with dueDate <= today
     */
    private fun loadTodayTasks(context: Context): List<WidgetTask> {
        val dbTasks = WidgetDatabaseHelper.loadTodayTasks(context)
        return dbTasks.map { task ->
            WidgetTask(
                id = task.id,
                title = task.title,
                isCompleted = task.isCompleted,
                priority = task.priority,
                dueTime = task.dueTime
            )
        }
    }

    /**
     * Create Small Widget (2x2): Header + 3 Tasks + Time
     * Shows 3 tasks at a time, rotates to next page on each data refresh when > 3 tasks.
     * Supports multiple skin themes with dynamic background and text colors.
     *
     * Task row click behavior controlled by tapTextToComplete setting:
     * - true: clicking anywhere on task row (including title) toggles completion
     * - false: only checkbox toggles completion, clicking title opens app
     *
     * @param widgetWidth Actual widget width in pixels (for dynamic background sizing)
     * @param widgetHeight Actual widget height in pixels (for dynamic background sizing)
     */
    private fun createSmallWidget(
        context: Context,
        tasks: List<WidgetTask>,
        widgetWidth: Int = 0,
        widgetHeight: Int = 0
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_small)

        // Load skin setting from SharedPreferences
        val skinConfig = loadWidgetSkin(context)

        // Load tap text to complete setting
        val tapTextToComplete = loadTapTextToComplete(context)

        // Background Image Config (contrast skins use background image)
        // Use setImageViewBitmap with code-drawn rounded corners (clipToOutline doesn't work in RemoteViews)
        if (skinConfig.backgroundImageRes != 0) {
            // Contrast skin: create bitmap with rounded corners via code
            views.setViewVisibility(R.id.widget_bg_image, View.VISIBLE)

            // Use actual widget size for bitmap, fallback to reasonable defaults
            val bitmapWidth = if (widgetWidth > 0) widgetWidth else 400
            val bitmapHeight = if (widgetHeight > 0) widgetHeight else 400

            val roundedBitmap = getScaledBitmap(context, skinConfig.backgroundImageRes, bitmapWidth, bitmapHeight)
            if (roundedBitmap != null) {
                views.setImageViewBitmap(R.id.widget_bg_image, roundedBitmap)
            } else {
                // Fallback: use resource directly if bitmap creation fails
                views.setImageViewResource(R.id.widget_bg_image, skinConfig.backgroundImageRes)
            }

            // Make root and container transparent since image has its own rounded corners
            views.setInt(R.id.widget_root, "setBackgroundResource", android.R.color.transparent)
            views.setInt(R.id.widget_container, "setBackgroundResource", android.R.color.transparent)
        } else {
            // Normal skin: set gradient background on root (XML drawable handles corners)
            views.setViewVisibility(R.id.widget_bg_image, View.GONE)
            views.setInt(R.id.widget_root, "setBackgroundResource", skinConfig.backgroundRes)
            views.setInt(R.id.widget_container, "setBackgroundResource", android.R.color.transparent)
        }

        // Apply skin color to header title
        views.setTextColor(R.id.widget_title, skinConfig.textColor)

        // Get today's incomplete tasks (today + overdue)
        val todayTasks = filterTodayTasks(tasks)
        val totalTasks = todayTasks.size

        // Pagination: 5 tasks per page
        val tasksPerPage = 5
        val totalPages = if (totalTasks == 0) 1 else (totalTasks + tasksPerPage - 1) / tasksPerPage
        val prefs = context.getSharedPreferences("amber_widget_prefs", Context.MODE_PRIVATE)
        var currentPage = prefs.getInt("small_widget_page", 0)

        // Ensure page is valid
        if (currentPage >= totalPages) currentPage = 0

        // Get tasks for current page
        val startIndex = currentPage * tasksPerPage
        val pageTasks = todayTasks.drop(startIndex).take(tasksPerPage)

        // Task item IDs (5 items per page)
        val taskIds = arrayOf(R.id.task_item_1, R.id.task_item_2, R.id.task_item_3, R.id.task_item_4, R.id.task_item_5)
        val titleIds = arrayOf(R.id.task_title_1, R.id.task_title_2, R.id.task_title_3, R.id.task_title_4, R.id.task_title_5)
        val checkboxIds = arrayOf(R.id.task_checkbox_1, R.id.task_checkbox_2, R.id.task_checkbox_3, R.id.task_checkbox_4, R.id.task_checkbox_5)
        val priorityIds = arrayOf(R.id.task_priority_1, R.id.task_priority_2, R.id.task_priority_3, R.id.task_priority_4, R.id.task_priority_5)

        if (pageTasks.isNotEmpty()) {
            // Hide empty state
            views.setViewVisibility(R.id.empty_state, View.GONE)

            // Show page indicator and next page button if multiple pages
            if (totalPages > 1) {
                views.setViewVisibility(R.id.page_indicator, View.VISIBLE)
                views.setTextViewText(R.id.page_indicator, "${currentPage + 1}/$totalPages")
                views.setTextColor(R.id.page_indicator, skinConfig.secondaryTextColor)
                // Show next page button with skin color
                views.setViewVisibility(R.id.btn_next_page, View.VISIBLE)
                views.setInt(R.id.btn_next_page, "setColorFilter", skinConfig.secondaryTextColor)
                // Set click listener for next page button
                val nextPageIntent = Intent(context, AmberWidgetProvider::class.java).apply {
                    action = ACTION_NEXT_PAGE
                }
                val nextPagePendingIntent = PendingIntent.getBroadcast(
                    context, 1001, nextPageIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.btn_next_page, nextPagePendingIntent)
            } else {
                views.setViewVisibility(R.id.page_indicator, View.GONE)
                views.setViewVisibility(R.id.btn_next_page, View.GONE)
            }

            // Show tasks
            for (i in 0 until tasksPerPage) {
                if (i < pageTasks.size) {
                    val task = pageTasks[i]
                    views.setViewVisibility(taskIds[i], View.VISIBLE)
                    views.setTextViewText(titleIds[i], task.title)
                    views.setTextColor(titleIds[i], skinConfig.textColor)
                    views.setImageViewResource(checkboxIds[i], R.drawable.ic_checkbox_unchecked)

                    // Set checkbox click listener for direct task toggle
                    val toggleIntent = Intent(context, AmberWidgetProvider::class.java).apply {
                        action = ACTION_TOGGLE_TASK_DIRECT
                        putExtra(EXTRA_TASK_ID, task.id)
                    }
                    val togglePendingIntent = PendingIntent.getBroadcast(
                        context, 2000 + i, toggleIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(checkboxIds[i], togglePendingIntent)

                    // Task title/row click behavior based on tapTextToComplete setting
                    if (tapTextToComplete) {
                        // Clicking title also toggles task completion
                        views.setOnClickPendingIntent(titleIds[i], togglePendingIntent)
                        views.setOnClickPendingIntent(taskIds[i], togglePendingIntent)
                    } else {
                        // Clicking title opens app
                        val openAppIntent = Intent(context, AmberWidgetProvider::class.java).apply {
                            action = ACTION_OPEN_APP
                        }
                        val openAppPendingIntent = PendingIntent.getBroadcast(
                            context, 4000 + i, openAppIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        views.setOnClickPendingIntent(titleIds[i], openAppPendingIntent)
                        views.setOnClickPendingIntent(taskIds[i], openAppPendingIntent)
                    }

                    // Priority flag icon (uses skin-specific medium priority icon to avoid color clash)
                    val priorityIcon = when (task.priority) {
                        3 -> R.drawable.ic_flag_high         // High - Red flag
                        2 -> skinConfig.mediumPriorityIconRes // Medium - skin-specific
                        1 -> R.drawable.ic_flag_low          // Low - Green flag
                        else -> R.drawable.ic_flag_none      // None - Gray flag
                    }
                    if (task.priority > 0) {
                        views.setViewVisibility(priorityIds[i], View.VISIBLE)
                        views.setImageViewResource(priorityIds[i], priorityIcon)
                    } else {
                        views.setViewVisibility(priorityIds[i], View.GONE)
                    }
                } else {
                    views.setViewVisibility(taskIds[i], View.GONE)
                }
            }

            // Always show current time with skin color
            val currentTime = java.text.SimpleDateFormat("HH:mm", java.util.Locale.getDefault())
                .format(java.util.Date())
            views.setTextViewText(R.id.time_text, currentTime)
            views.setTextColor(R.id.time_text, skinConfig.secondaryTextColor)
        } else {
            // No tasks - show empty state
            views.setViewVisibility(R.id.empty_state, View.VISIBLE)
            views.setTextColor(R.id.empty_state, skinConfig.secondaryTextColor)
            views.setViewVisibility(R.id.page_indicator, View.GONE)
            views.setViewVisibility(R.id.btn_next_page, View.GONE)
            for (i in 0 until tasksPerPage) {
                views.setViewVisibility(taskIds[i], View.GONE)
            }
            views.setTextViewText(R.id.time_text, "--:--")
            views.setTextColor(R.id.time_text, skinConfig.secondaryTextColor)
        }

        // Set click to open app
        val openIntent = Intent(context, AmberWidgetProvider::class.java).apply {
            action = ACTION_OPEN_APP
        }
        val openPendingIntent = PendingIntent.getBroadcast(
            context, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_container, openPendingIntent)

        return views
    }

    /**
     * Create Medium Widget (4x2): Left(Date) + Right(Tasks)
     * Shows date info on left, task list on right
     * Supports multiple skin themes with dynamic background and text colors.
     *
     * Task row click behavior controlled by tapTextToComplete setting:
     * - true: clicking anywhere on task row (including title) toggles completion
     * - false: only checkbox toggles completion, clicking title opens app
     *
     * @param widgetWidth Actual widget width in pixels (for dynamic background sizing)
     * @param widgetHeight Actual widget height in pixels (for dynamic background sizing)
     */
    private fun createMediumWidget(
        context: Context,
        tasks: List<WidgetTask>,
        widgetWidth: Int = 0,
        widgetHeight: Int = 0
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_medium)

        // Load skin setting from SharedPreferences
        val skinConfig = loadWidgetSkin(context)

        // Load tap text to complete setting
        val tapTextToComplete = loadTapTextToComplete(context)

        // Apply skin background (contrast skins use Medium-specific image)
        // Use setImageViewBitmap with code-drawn rounded corners (clipToOutline doesn't work in RemoteViews)
        if (skinConfig.backgroundImageMediumRes != 0) {
            // Contrast skin: create bitmap with rounded corners via code
            views.setViewVisibility(R.id.widget_bg_image, View.VISIBLE)

            // Use actual widget size for bitmap, fallback to reasonable defaults for 4x2 ratio
            val bitmapWidth = if (widgetWidth > 0) widgetWidth else 800
            val bitmapHeight = if (widgetHeight > 0) widgetHeight else 400

            val roundedBitmap = getScaledBitmap(context, skinConfig.backgroundImageMediumRes, bitmapWidth, bitmapHeight)
            if (roundedBitmap != null) {
                views.setImageViewBitmap(R.id.widget_bg_image, roundedBitmap)
            } else {
                // Fallback: use resource directly if bitmap creation fails
                views.setImageViewResource(R.id.widget_bg_image, skinConfig.backgroundImageMediumRes)
            }

            // Make root and container transparent since image has its own rounded corners
            views.setInt(R.id.widget_root, "setBackgroundResource", android.R.color.transparent)
            views.setInt(R.id.widget_container, "setBackgroundResource", android.R.color.transparent)
        } else {
            // Normal skin: set gradient background on root (XML drawable handles corners)
            views.setViewVisibility(R.id.widget_bg_image, View.GONE)
            views.setInt(R.id.widget_root, "setBackgroundResource", skinConfig.backgroundRes)
            views.setInt(R.id.widget_container, "setBackgroundResource", android.R.color.transparent)
        }

        // Apply skin color to header title (今日任务)
        views.setTextColor(R.id.header_title, skinConfig.textColor)

        // Set date info on left side
        val calendar = java.util.Calendar.getInstance()
        val day = String.format("%02d", calendar.get(java.util.Calendar.DAY_OF_MONTH))
        val month = "${calendar.get(java.util.Calendar.MONTH) + 1}月"
        val weekdays = arrayOf("星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六")
        val weekday = weekdays[calendar.get(java.util.Calendar.DAY_OF_WEEK) - 1]
        val lunarInfo = getLunarDateFull(calendar)

        views.setTextViewText(R.id.date_day, day)
        views.setTextViewText(R.id.date_month, month)  // Solar month capsule: "1月"
        views.setTextViewText(R.id.date_lunar, "${lunarInfo.first}${lunarInfo.second}")  // Lunar: "腊月二十"
        views.setTextViewText(R.id.date_weekday, weekday)

        // Apply skin colors to date section
        views.setTextColor(R.id.date_day, skinConfig.textColor)
        views.setTextColor(R.id.date_lunar, skinConfig.secondaryTextColor)
        views.setTextColor(R.id.date_weekday, skinConfig.secondaryTextColor)

        // Get today's incomplete tasks (today + overdue)
        val todayTasks = filterTodayTasks(tasks)
        val totalTasks = todayTasks.size

        // Pagination: 5 tasks per page (same as small widget)
        val tasksPerPage = 5
        val totalPages = if (totalTasks == 0) 1 else (totalTasks + tasksPerPage - 1) / tasksPerPage
        val prefs = context.getSharedPreferences("amber_widget_prefs", Context.MODE_PRIVATE)
        var currentPage = prefs.getInt("medium_widget_page", 0)

        // Ensure page is valid
        if (currentPage >= totalPages) currentPage = 0

        // Get tasks for current page
        val startIndex = currentPage * tasksPerPage
        val pageTasks = todayTasks.drop(startIndex).take(tasksPerPage)

        // Task item IDs
        val taskIds = arrayOf(R.id.task_item_1, R.id.task_item_2, R.id.task_item_3, R.id.task_item_4, R.id.task_item_5)
        val titleIds = arrayOf(R.id.task_title_1, R.id.task_title_2, R.id.task_title_3, R.id.task_title_4, R.id.task_title_5)
        val checkboxIds = arrayOf(R.id.task_checkbox_1, R.id.task_checkbox_2, R.id.task_checkbox_3, R.id.task_checkbox_4, R.id.task_checkbox_5)
        val priorityIds = arrayOf(R.id.task_priority_1, R.id.task_priority_2, R.id.task_priority_3, R.id.task_priority_4, R.id.task_priority_5)

        if (pageTasks.isNotEmpty()) {
            views.setViewVisibility(R.id.empty_state, View.GONE)

            // Show page indicator and next page button if multiple pages
            if (totalPages > 1) {
                views.setViewVisibility(R.id.page_indicator, View.VISIBLE)
                views.setTextViewText(R.id.page_indicator, "${currentPage + 1}/$totalPages")
                views.setTextColor(R.id.page_indicator, skinConfig.secondaryTextColor)
                views.setViewVisibility(R.id.btn_next_page, View.VISIBLE)
                views.setInt(R.id.btn_next_page, "setColorFilter", skinConfig.secondaryTextColor)

                // Set click listener for next page button
                val nextPageIntent = Intent(context, AmberWidgetMediumProvider::class.java).apply {
                    action = ACTION_NEXT_PAGE_MEDIUM
                }
                val nextPagePendingIntent = PendingIntent.getBroadcast(
                    context, 1002, nextPageIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.btn_next_page, nextPagePendingIntent)
            } else {
                views.setViewVisibility(R.id.page_indicator, View.GONE)
                views.setViewVisibility(R.id.btn_next_page, View.GONE)
            }

            for (i in 0 until tasksPerPage) {
                if (i < pageTasks.size) {
                    val task = pageTasks[i]
                    views.setViewVisibility(taskIds[i], View.VISIBLE)
                    views.setTextViewText(titleIds[i], task.title)
                    views.setTextColor(titleIds[i], skinConfig.textColor)
                    views.setImageViewResource(checkboxIds[i], R.drawable.ic_checkbox_unchecked)

                    // Set checkbox click listener for direct task toggle
                    val toggleIntent = Intent(context, AmberWidgetMediumProvider::class.java).apply {
                        action = ACTION_TOGGLE_TASK_DIRECT
                        putExtra(EXTRA_TASK_ID, task.id)
                    }
                    val togglePendingIntent = PendingIntent.getBroadcast(
                        context, 3000 + i, toggleIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(checkboxIds[i], togglePendingIntent)

                    // Task title/row click behavior based on tapTextToComplete setting
                    if (tapTextToComplete) {
                        // Clicking title also toggles task completion
                        views.setOnClickPendingIntent(titleIds[i], togglePendingIntent)
                        views.setOnClickPendingIntent(taskIds[i], togglePendingIntent)
                    } else {
                        // Clicking title opens app
                        val openAppIntent = Intent(context, AmberWidgetMediumProvider::class.java).apply {
                            action = ACTION_OPEN_APP
                        }
                        val openAppPendingIntent = PendingIntent.getBroadcast(
                            context, 5000 + i, openAppIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        views.setOnClickPendingIntent(titleIds[i], openAppPendingIntent)
                        views.setOnClickPendingIntent(taskIds[i], openAppPendingIntent)
                    }

                    // Priority flag icon (uses skin-specific medium priority icon to avoid color clash)
                    val priorityIcon = when (task.priority) {
                        3 -> R.drawable.ic_flag_high         // High - Red flag
                        2 -> skinConfig.mediumPriorityIconRes // Medium - skin-specific
                        1 -> R.drawable.ic_flag_low          // Low - Green flag
                        else -> R.drawable.ic_flag_none      // None - Gray flag
                    }
                    if (task.priority > 0) {
                        views.setViewVisibility(priorityIds[i], View.VISIBLE)
                        views.setImageViewResource(priorityIds[i], priorityIcon)
                    } else {
                        views.setViewVisibility(priorityIds[i], View.GONE)
                    }
                } else {
                    views.setViewVisibility(taskIds[i], View.GONE)
                }
            }
        } else {
            views.setViewVisibility(R.id.empty_state, View.VISIBLE)
            views.setTextColor(R.id.empty_state, skinConfig.secondaryTextColor)
            views.setViewVisibility(R.id.page_indicator, View.GONE)
            views.setViewVisibility(R.id.btn_next_page, View.GONE)
            for (i in 0 until tasksPerPage) {
                views.setViewVisibility(taskIds[i], View.GONE)
            }
        }

        // Set click to open app
        val openIntent = Intent(context, AmberWidgetProvider::class.java).apply {
            action = ACTION_OPEN_APP
        }
        val openPendingIntent = PendingIntent.getBroadcast(
            context, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_container, openPendingIntent)

        return views
    }

    /**
     * Create Large Widget (4x4): Calendar Month View
     * Shows a full month calendar with Chinese holidays and task indicators
     * Supports multiple skin themes with dynamic background and text colors.
     *
     * @param widgetWidth Actual widget width in pixels (for dynamic background sizing)
     * @param widgetHeight Actual widget height in pixels (for dynamic background sizing)
     */
    private fun createLargeWidget(
        context: Context,
        tasks: List<WidgetTask>,
        widgetWidth: Int = 0,
        widgetHeight: Int = 0
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_large)

        // Load skin setting from SharedPreferences
        val skinConfig = loadWidgetSkin(context)

        // Apply skin background (contrast skins use Large-specific image)
        // Use setImageViewBitmap with code-drawn rounded corners (clipToOutline doesn't work in RemoteViews)
        if (skinConfig.backgroundImageLargeRes != 0) {
            // Contrast skin: create bitmap with rounded corners via code
            views.setViewVisibility(R.id.widget_bg_image, View.VISIBLE)

            // Use actual widget size for bitmap, fallback to reasonable defaults for 4x4 ratio
            val bitmapWidth = if (widgetWidth > 0) widgetWidth else 800
            val bitmapHeight = if (widgetHeight > 0) widgetHeight else 800

            val roundedBitmap = getScaledBitmap(context, skinConfig.backgroundImageLargeRes, bitmapWidth, bitmapHeight)
            if (roundedBitmap != null) {
                views.setImageViewBitmap(R.id.widget_bg_image, roundedBitmap)
            } else {
                // Fallback: use resource directly if bitmap creation fails
                views.setImageViewResource(R.id.widget_bg_image, skinConfig.backgroundImageLargeRes)
            }

            // Make root and container transparent since image has its own rounded corners
            views.setInt(R.id.widget_root, "setBackgroundResource", android.R.color.transparent)
            views.setInt(R.id.widget_container, "setBackgroundResource", android.R.color.transparent)
            views.setInt(R.id.widget_header, "setBackgroundResource", R.drawable.widget_header_background)
        } else {
            // Normal skin: set gradient background on root (XML drawable handles corners)
            views.setViewVisibility(R.id.widget_bg_image, View.GONE)
            views.setInt(R.id.widget_root, "setBackgroundResource", skinConfig.backgroundRes)
            views.setInt(R.id.widget_container, "setBackgroundResource", android.R.color.transparent)
            views.setInt(R.id.widget_header, "setBackgroundResource", skinConfig.headerBackgroundRes)
        }

        // Get month offset from prefs (0 = current month)
        val prefs = context.getSharedPreferences("amber_widget_prefs", Context.MODE_PRIVATE)
        val monthOffset = prefs.getInt("large_widget_month_offset", 0)

        // Calculate display month/year
        val today = java.util.Calendar.getInstance()
        val displayCal = java.util.Calendar.getInstance()
        displayCal.add(java.util.Calendar.MONTH, monthOffset)
        val displayYear = displayCal.get(java.util.Calendar.YEAR)
        val displayMonth = displayCal.get(java.util.Calendar.MONTH) + 1 // 1-12

        // Set header year-month text with skin color
        views.setTextViewText(R.id.header_year_month, "${displayYear}年${displayMonth}月")
        views.setTextColor(R.id.header_year_month, skinConfig.headerTextColor)

        // Apply header navigation button colors
        views.setTextColor(R.id.btn_prev_month, skinConfig.headerTextColor)
        views.setTextColor(R.id.btn_today, skinConfig.headerTextColor)
        views.setTextColor(R.id.btn_next_month, skinConfig.headerTextColor)

        // Set navigation button click handlers
        setupCalendarNavigation(context, views)

        // Calculate calendar grid
        // First, find the first day of the month
        displayCal.set(java.util.Calendar.DAY_OF_MONTH, 1)
        val firstDayOfWeek = displayCal.get(java.util.Calendar.DAY_OF_WEEK) // 1=Sun, 7=Sat
        val daysInMonth = displayCal.getActualMaximum(java.util.Calendar.DAY_OF_MONTH)

        // Calculate previous month info for leading days
        val prevMonthCal = java.util.Calendar.getInstance()
        prevMonthCal.time = displayCal.time
        prevMonthCal.add(java.util.Calendar.MONTH, -1)
        val daysInPrevMonth = prevMonthCal.getActualMaximum(java.util.Calendar.DAY_OF_MONTH)
        val prevYear = prevMonthCal.get(java.util.Calendar.YEAR)
        val prevMonth = prevMonthCal.get(java.util.Calendar.MONTH) + 1

        // Calculate next month info
        val nextMonthCal = java.util.Calendar.getInstance()
        nextMonthCal.time = displayCal.time
        nextMonthCal.add(java.util.Calendar.MONTH, 1)
        val nextYear = nextMonthCal.get(java.util.Calendar.YEAR)
        val nextMonth = nextMonthCal.get(java.util.Calendar.MONTH) + 1

        // Build task date map (YYYY-MM-DD -> has task)
        val taskDates = mutableSetOf<String>()
        for (task in tasks) {
            task.dueTime?.let { dueTime ->
                // Extract date from dueTime (format: YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS)
                val dateOnly = dueTime.substring(0, minOf(10, dueTime.length))
                taskDates.add(dateOnly)
            }
        }

        // Today info for highlighting
        val todayYear = today.get(java.util.Calendar.YEAR)
        val todayMonth = today.get(java.util.Calendar.MONTH) + 1
        val todayDay = today.get(java.util.Calendar.DAY_OF_MONTH)

        // Day cell resource ID arrays
        val dayCellIds = getDayCellIds()
        val dayNumIds = getDayNumIds()
        val dayBadgeIds = getDayBadgeIds()
        val dayCircleIds = getDayCircleIds()

        // Populate 42 day cells
        var cellIndex = 0

        // Leading days from previous month
        val leadingDays = firstDayOfWeek - 1 // How many days before 1st
        for (i in leadingDays downTo 1) {
            val dayNum = daysInPrevMonth - i + 1
            populateDayCell(
                views, context, cellIndex,
                dayCellIds, dayNumIds, dayBadgeIds, dayCircleIds,
                prevYear, prevMonth, dayNum,
                todayYear, todayMonth, todayDay,
                taskDates, isCurrentMonth = false, skinConfig
            )
            cellIndex++
        }

        // Current month days
        for (day in 1..daysInMonth) {
            populateDayCell(
                views, context, cellIndex,
                dayCellIds, dayNumIds, dayBadgeIds, dayCircleIds,
                displayYear, displayMonth, day,
                todayYear, todayMonth, todayDay,
                taskDates, isCurrentMonth = true, skinConfig
            )
            cellIndex++
        }

        // Trailing days from next month
        while (cellIndex < 42) {
            val dayNum = cellIndex - leadingDays - daysInMonth + 1
            populateDayCell(
                views, context, cellIndex,
                dayCellIds, dayNumIds, dayBadgeIds, dayCircleIds,
                nextYear, nextMonth, dayNum,
                todayYear, todayMonth, todayDay,
                taskDates, isCurrentMonth = false, skinConfig
            )
            cellIndex++
        }

        // Header click to open app
        val openIntent = Intent(context, AmberWidgetProvider::class.java).apply {
            action = ACTION_OPEN_APP
        }
        val openPendingIntent = PendingIntent.getBroadcast(
            context, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_header, openPendingIntent)

        return views
    }

    /**
     * Setup calendar navigation button click handlers
     */
    private fun setupCalendarNavigation(context: Context, views: RemoteViews) {
        // Previous month button
        val prevIntent = Intent(context, AmberWidgetLargeProvider::class.java).apply {
            action = ACTION_PREV_MONTH
        }
        val prevPendingIntent = PendingIntent.getBroadcast(
            context, 2001, prevIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.btn_prev_month, prevPendingIntent)

        // Next month button
        val nextIntent = Intent(context, AmberWidgetLargeProvider::class.java).apply {
            action = ACTION_NEXT_MONTH
        }
        val nextPendingIntent = PendingIntent.getBroadcast(
            context, 2002, nextIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.btn_next_month, nextPendingIntent)

        // Today button
        val todayIntent = Intent(context, AmberWidgetLargeProvider::class.java).apply {
            action = ACTION_TODAY
        }
        val todayPendingIntent = PendingIntent.getBroadcast(
            context, 2003, todayIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.btn_today, todayPendingIntent)
    }

    /**
     * Populate a single day cell with date, holiday badge, and circle indicator
     * Supports skin-based text colors for dark/light themes
     */
    private fun populateDayCell(
        views: RemoteViews,
        context: Context,
        cellIndex: Int,
        dayCellIds: IntArray,
        dayNumIds: IntArray,
        dayBadgeIds: IntArray,
        dayCircleIds: IntArray,
        year: Int,
        month: Int,
        day: Int,
        todayYear: Int,
        todayMonth: Int,
        todayDay: Int,
        taskDates: Set<String>,
        isCurrentMonth: Boolean,
        skinConfig: WidgetSkinConfig
    ) {
        val dayNumId = dayNumIds[cellIndex]
        val dayBadgeId = dayBadgeIds[cellIndex]
        val dayCircleId = dayCircleIds[cellIndex]
        val dayCellId = dayCellIds[cellIndex]

        // Set day number
        views.setTextViewText(dayNumId, day.toString())

        // Check if this date has tasks
        val dateKey = String.format("%04d-%02d-%02d", year, month, day)
        val hasTask = taskDates.contains(dateKey)

        // Determine text color and circle based on:
        // 1. Current month vs other months (dimmed color from skin)
        // 2. Today (white text with amber circle background)
        // 3. Has task (red hand-drawn circle)
        // 4. Weekend (Sunday = red, Saturday = blue)
        val isToday = (year == todayYear && month == todayMonth && day == todayDay)
        val dayOfWeek = (cellIndex % 7) // 0=Sun, 6=Sat

        val textColor = when {
            !isCurrentMonth -> skinConfig.secondaryTextColor // Dimmed for other months
            isToday -> Color.parseColor("#FFFFFF") // White for today
            dayOfWeek == 0 -> Color.parseColor("#E53935") // Red for Sunday
            dayOfWeek == 6 -> Color.parseColor("#64B5F6") // Light blue for Saturday (visible on dark)
            else -> skinConfig.textColor // Use skin text color
        }
        views.setTextColor(dayNumId, textColor)

        // Circle indicator: Today (amber filled) or has task (red ring)
        if (isToday && isCurrentMonth) {
            // Today: amber filled circle background on day_num
            views.setInt(dayNumId, "setBackgroundResource", R.drawable.widget_today_circle)
            // Also show task circle if has task (red ring around amber)
            if (hasTask) {
                views.setViewVisibility(dayCircleId, View.VISIBLE)
                views.setImageViewResource(dayCircleId, R.drawable.widget_task_circle)
            } else {
                views.setViewVisibility(dayCircleId, View.GONE)
            }
        } else if (hasTask && isCurrentMonth) {
            // Has task: red hand-drawn circle
            views.setInt(dayNumId, "setBackgroundResource", 0)
            views.setViewVisibility(dayCircleId, View.VISIBLE)
            views.setImageViewResource(dayCircleId, R.drawable.widget_task_circle)
        } else {
            // No highlight
            views.setInt(dayNumId, "setBackgroundResource", 0)
            views.setViewVisibility(dayCircleId, View.GONE)
        }

        // Holiday badge
        val holidayInfo = ChineseHolidays.getHolidayInfo(year, month, day)
        if (holidayInfo != null && isCurrentMonth) {
            views.setViewVisibility(dayBadgeId, View.VISIBLE)
            views.setTextViewText(dayBadgeId, holidayInfo.name)
            // "班" in different color (blue for work day)
            val badgeColor = if (holidayInfo.isRestDay) {
                Color.parseColor("#E53935") // Red for holiday
            } else {
                Color.parseColor("#1976D2") // Blue for makeup workday
            }
            views.setTextColor(dayBadgeId, badgeColor)
        } else {
            views.setViewVisibility(dayBadgeId, View.GONE)
        }

        // Day cell click - open app to specific date
        val dayClickIntent = Intent(context, AmberWidgetLargeProvider::class.java).apply {
            action = ACTION_OPEN_DAY
            putExtra(EXTRA_DAY_DATE, dateKey)
        }
        val dayClickPendingIntent = PendingIntent.getBroadcast(
            context, 3000 + cellIndex, dayClickIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(dayCellId, dayClickPendingIntent)
    }

    /**
     * Get array of day cell FrameLayout IDs (day_0 to day_41)
     */
    private fun getDayCellIds(): IntArray {
        return intArrayOf(
            R.id.day_0, R.id.day_1, R.id.day_2, R.id.day_3, R.id.day_4, R.id.day_5, R.id.day_6,
            R.id.day_7, R.id.day_8, R.id.day_9, R.id.day_10, R.id.day_11, R.id.day_12, R.id.day_13,
            R.id.day_14, R.id.day_15, R.id.day_16, R.id.day_17, R.id.day_18, R.id.day_19, R.id.day_20,
            R.id.day_21, R.id.day_22, R.id.day_23, R.id.day_24, R.id.day_25, R.id.day_26, R.id.day_27,
            R.id.day_28, R.id.day_29, R.id.day_30, R.id.day_31, R.id.day_32, R.id.day_33, R.id.day_34,
            R.id.day_35, R.id.day_36, R.id.day_37, R.id.day_38, R.id.day_39, R.id.day_40, R.id.day_41
        )
    }

    /**
     * Get array of day number TextView IDs (day_num_0 to day_num_41)
     */
    private fun getDayNumIds(): IntArray {
        return intArrayOf(
            R.id.day_num_0, R.id.day_num_1, R.id.day_num_2, R.id.day_num_3, R.id.day_num_4, R.id.day_num_5, R.id.day_num_6,
            R.id.day_num_7, R.id.day_num_8, R.id.day_num_9, R.id.day_num_10, R.id.day_num_11, R.id.day_num_12, R.id.day_num_13,
            R.id.day_num_14, R.id.day_num_15, R.id.day_num_16, R.id.day_num_17, R.id.day_num_18, R.id.day_num_19, R.id.day_num_20,
            R.id.day_num_21, R.id.day_num_22, R.id.day_num_23, R.id.day_num_24, R.id.day_num_25, R.id.day_num_26, R.id.day_num_27,
            R.id.day_num_28, R.id.day_num_29, R.id.day_num_30, R.id.day_num_31, R.id.day_num_32, R.id.day_num_33, R.id.day_num_34,
            R.id.day_num_35, R.id.day_num_36, R.id.day_num_37, R.id.day_num_38, R.id.day_num_39, R.id.day_num_40, R.id.day_num_41
        )
    }

    /**
     * Get array of day badge TextView IDs (day_badge_0 to day_badge_41)
     */
    private fun getDayBadgeIds(): IntArray {
        return intArrayOf(
            R.id.day_badge_0, R.id.day_badge_1, R.id.day_badge_2, R.id.day_badge_3, R.id.day_badge_4, R.id.day_badge_5, R.id.day_badge_6,
            R.id.day_badge_7, R.id.day_badge_8, R.id.day_badge_9, R.id.day_badge_10, R.id.day_badge_11, R.id.day_badge_12, R.id.day_badge_13,
            R.id.day_badge_14, R.id.day_badge_15, R.id.day_badge_16, R.id.day_badge_17, R.id.day_badge_18, R.id.day_badge_19, R.id.day_badge_20,
            R.id.day_badge_21, R.id.day_badge_22, R.id.day_badge_23, R.id.day_badge_24, R.id.day_badge_25, R.id.day_badge_26, R.id.day_badge_27,
            R.id.day_badge_28, R.id.day_badge_29, R.id.day_badge_30, R.id.day_badge_31, R.id.day_badge_32, R.id.day_badge_33, R.id.day_badge_34,
            R.id.day_badge_35, R.id.day_badge_36, R.id.day_badge_37, R.id.day_badge_38, R.id.day_badge_39, R.id.day_badge_40, R.id.day_badge_41
        )
    }

    /**
     * Get array of day dot View IDs (day_dot_0 to day_dot_41)
     */
    private fun getDayCircleIds(): IntArray {
        return intArrayOf(
            R.id.day_circle_0, R.id.day_circle_1, R.id.day_circle_2, R.id.day_circle_3, R.id.day_circle_4, R.id.day_circle_5, R.id.day_circle_6,
            R.id.day_circle_7, R.id.day_circle_8, R.id.day_circle_9, R.id.day_circle_10, R.id.day_circle_11, R.id.day_circle_12, R.id.day_circle_13,
            R.id.day_circle_14, R.id.day_circle_15, R.id.day_circle_16, R.id.day_circle_17, R.id.day_circle_18, R.id.day_circle_19, R.id.day_circle_20,
            R.id.day_circle_21, R.id.day_circle_22, R.id.day_circle_23, R.id.day_circle_24, R.id.day_circle_25, R.id.day_circle_26, R.id.day_circle_27,
            R.id.day_circle_28, R.id.day_circle_29, R.id.day_circle_30, R.id.day_circle_31, R.id.day_circle_32, R.id.day_circle_33, R.id.day_circle_34,
            R.id.day_circle_35, R.id.day_circle_36, R.id.day_circle_37, R.id.day_circle_38, R.id.day_circle_39, R.id.day_circle_40, R.id.day_circle_41
        )
    }

    /**
     * Widget size enum - protected so subclasses can access
     */
    protected enum class WidgetSize {
        SMALL,   // 2x2
        MEDIUM,  // 4x2
        LARGE    // 4x4
    }

    /**
     * Task data class for widget display
     */
    private data class WidgetTask(
        val id: String,
        val title: String,
        val isCompleted: Boolean,
        val priority: Int,
        val dueTime: String? = null
    )

    /**
     * Filter tasks for today view (Small/Medium widgets)
     * Returns incomplete tasks with dueDate == today (only today's tasks)
     *
     * Note: Overdue tasks are NOT shown in the widget.
     * The auto-postpone feature (which moves overdue tasks to today) is handled
     * by the Flutter app on startup, not by the widget.
     */
    private fun filterTodayTasks(tasks: List<WidgetTask>): List<WidgetTask> {
        val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.getDefault())
            .format(java.util.Date())

        return tasks.filter { task ->
            // Must be incomplete
            if (task.isCompleted) return@filter false

            // Must have due date
            val dueTime = task.dueTime ?: return@filter false

            // Due date == today (only today's tasks, not overdue)
            dueTime == today
        }
    }

    /**
     * Get full lunar date info (month + day) from calendar
     * Returns Pair<lunarMonth, lunarDay> e.g. ("冬月", "初九")
     *
     * Using known lunar month start dates for accurate calculation.
     * Reference: 2024-2026 lunar calendar data
     */
    private fun getLunarDateFull(calendar: java.util.Calendar): Pair<String, String> {
        val lunarDays = arrayOf(
            "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
            "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
            "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"
        )

        val lunarMonths = arrayOf(
            "正月", "二月", "三月", "四月", "五月", "六月",
            "七月", "八月", "九月", "十月", "冬月", "腊月"
        )

        // Known lunar month start dates (solar calendar dates for 初一 of each lunar month)
        // Format: year, month(0-indexed), day -> lunarMonth(1-12)
        // Data source: Chinese lunar calendar 2024-2026
        data class LunarMonthStart(val year: Int, val month: Int, val day: Int, val lunarMonth: Int, val lunarYear: Int)

        val lunarMonthStarts = listOf(
            // 甲辰年 (2024 lunar year)
            LunarMonthStart(2024, 1, 10, 1, 2024),   // 正月初一 Feb 10
            LunarMonthStart(2024, 2, 10, 2, 2024),   // 二月初一 Mar 10
            LunarMonthStart(2024, 3, 9, 3, 2024),    // 三月初一 Apr 9
            LunarMonthStart(2024, 4, 8, 4, 2024),    // 四月初一 May 8
            LunarMonthStart(2024, 5, 6, 5, 2024),    // 五月初一 Jun 6
            LunarMonthStart(2024, 6, 6, 6, 2024),    // 六月初一 Jul 6
            LunarMonthStart(2024, 7, 4, 7, 2024),    // 七月初一 Aug 4
            LunarMonthStart(2024, 8, 3, 8, 2024),    // 八月初一 Sep 3
            LunarMonthStart(2024, 9, 3, 9, 2024),    // 九月初一 Oct 3
            LunarMonthStart(2024, 10, 1, 10, 2024),  // 十月初一 Nov 1
            LunarMonthStart(2024, 11, 1, 11, 2024),  // 冬月初一 Dec 1
            LunarMonthStart(2024, 11, 31, 12, 2024), // 腊月初一 Dec 31

            // 乙巳年 (2025 lunar year)
            LunarMonthStart(2025, 0, 29, 1, 2025),   // 正月初一 Jan 29
            LunarMonthStart(2025, 1, 28, 2, 2025),   // 二月初一 Feb 28
            LunarMonthStart(2025, 2, 29, 3, 2025),   // 三月初一 Mar 29
            LunarMonthStart(2025, 3, 28, 4, 2025),   // 四月初一 Apr 28
            LunarMonthStart(2025, 4, 27, 5, 2025),   // 五月初一 May 27
            LunarMonthStart(2025, 5, 25, 6, 2025),   // 六月初一 Jun 25 (闰六月 follows)
            LunarMonthStart(2025, 6, 25, 6, 2025),   // 闰六月初一 Jul 25
            LunarMonthStart(2025, 7, 23, 7, 2025),   // 七月初一 Aug 23
            LunarMonthStart(2025, 8, 22, 8, 2025),   // 八月初一 Sep 22
            LunarMonthStart(2025, 9, 21, 9, 2025),   // 九月初一 Oct 21
            LunarMonthStart(2025, 10, 20, 10, 2025), // 十月初一 Nov 20
            LunarMonthStart(2025, 11, 20, 11, 2025), // 冬月初一 Dec 20

            // 丙午年 (2026 lunar year)
            LunarMonthStart(2026, 0, 18, 12, 2025),  // 腊月初一 Jan 18 (still 2025 lunar)
            LunarMonthStart(2026, 1, 17, 1, 2026),   // 正月初一 Feb 17
        )

        try {
            val year = calendar.get(java.util.Calendar.YEAR)
            val month = calendar.get(java.util.Calendar.MONTH)
            val day = calendar.get(java.util.Calendar.DAY_OF_MONTH)

            // Find the lunar month this date belongs to
            var foundMonth: LunarMonthStart? = null

            for (i in lunarMonthStarts.indices.reversed()) {
                val lms = lunarMonthStarts[i]
                val startCal = java.util.Calendar.getInstance().apply {
                    set(lms.year, lms.month, lms.day, 0, 0, 0)
                    set(java.util.Calendar.MILLISECOND, 0)
                }
                val currentCal = java.util.Calendar.getInstance().apply {
                    set(year, month, day, 0, 0, 0)
                    set(java.util.Calendar.MILLISECOND, 0)
                }

                if (!currentCal.before(startCal)) {
                    foundMonth = lms
                    break
                }
            }

            if (foundMonth == null) {
                return Pair("正月", "初一")
            }

            // Calculate day within the lunar month
            val startCal = java.util.Calendar.getInstance().apply {
                set(foundMonth.year, foundMonth.month, foundMonth.day, 0, 0, 0)
                set(java.util.Calendar.MILLISECOND, 0)
            }
            val currentCal = java.util.Calendar.getInstance().apply {
                set(year, month, day, 0, 0, 0)
                set(java.util.Calendar.MILLISECOND, 0)
            }

            val daysDiff = ((currentCal.timeInMillis - startCal.timeInMillis) / 86400000).toInt()
            val lunarDay = daysDiff + 1 // 初一 is day 1

            val monthStr = if (foundMonth.lunarMonth in 1..12) lunarMonths[foundMonth.lunarMonth - 1] else "正月"
            val dayStr = if (lunarDay in 1..30) lunarDays[lunarDay - 1] else "三十"

            return Pair(monthStr, dayStr)
        } catch (e: Exception) {
            Log.e(TAG, "Error calculating lunar date", e)
            return Pair("正月", "初一")
        }
    }

    /**
     * Get lunar date string from calendar
     * Simple approximation - returns lunar day in Chinese
     */
    private fun getLunarDate(calendar: java.util.Calendar): String {
        // Lunar calendar calculation (simplified approximation)
        // Using ChineseLunarCalendar would be more accurate but requires additional library
        // This is a basic implementation for display purposes

        val lunarDays = arrayOf(
            "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
            "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
            "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"
        )

        val lunarMonths = arrayOf(
            "正月", "二月", "三月", "四月", "五月", "六月",
            "七月", "八月", "九月", "十月", "冬月", "腊月"
        )

        // Lunar calendar info array: each year from 1900-2100
        // Format: [leap month (0=none), days in each month (bit flags)]
        // This is a simplified calculation - for production use a proper lunar calendar library
        val lunarInfo = intArrayOf(
            0x04bd8, 0x04ae0, 0x0a570, 0x054d5, 0x0d260, 0x0d950, 0x16554, 0x056a0, 0x09ad0, 0x055d2,
            0x04ae0, 0x0a5b6, 0x0a4d0, 0x0d250, 0x1d255, 0x0b540, 0x0d6a0, 0x0ada2, 0x095b0, 0x14977,
            0x04970, 0x0a4b0, 0x0b4b5, 0x06a50, 0x06d40, 0x1ab54, 0x02b60, 0x09570, 0x052f2, 0x04970,
            0x06566, 0x0d4a0, 0x0ea50, 0x06e95, 0x05ad0, 0x02b60, 0x186e3, 0x092e0, 0x1c8d7, 0x0c950,
            0x0d4a0, 0x1d8a6, 0x0b550, 0x056a0, 0x1a5b4, 0x025d0, 0x092d0, 0x0d2b2, 0x0a950, 0x0b557,
            0x06ca0, 0x0b550, 0x15355, 0x04da0, 0x0a5b0, 0x14573, 0x052b0, 0x0a9a8, 0x0e950, 0x06aa0,
            0x0aea6, 0x0ab50, 0x04b60, 0x0aae4, 0x0a570, 0x05260, 0x0f263, 0x0d950, 0x05b57, 0x056a0,
            0x096d0, 0x04dd5, 0x04ad0, 0x0a4d0, 0x0d4d4, 0x0d250, 0x0d558, 0x0b540, 0x0b6a0, 0x195a6,
            0x095b0, 0x049b0, 0x0a974, 0x0a4b0, 0x0b27a, 0x06a50, 0x06d40, 0x0af46, 0x0ab60, 0x09570,
            0x04af5, 0x04970, 0x064b0, 0x074a3, 0x0ea50, 0x06b58, 0x055c0, 0x0ab60, 0x096d5, 0x092e0,
            0x0c960, 0x0d954, 0x0d4a0, 0x0da50, 0x07552, 0x056a0, 0x0abb7, 0x025d0, 0x092d0, 0x0cab5,
            0x0a950, 0x0b4a0, 0x0baa4, 0x0ad50, 0x055d9, 0x04ba0, 0x0a5b0, 0x15176, 0x052b0, 0x0a930,
            0x07954, 0x06aa0, 0x0ad50, 0x05b52, 0x04b60, 0x0a6e6, 0x0a4e0, 0x0d260, 0x0ea65, 0x0d530,
            0x05aa0, 0x076a3, 0x096d0, 0x04afb, 0x04ad0, 0x0a4d0, 0x1d0b6, 0x0d250, 0x0d520, 0x0dd45,
            0x0b5a0, 0x056d0, 0x055b2, 0x049b0, 0x0a577, 0x0a4b0, 0x0aa50, 0x1b255, 0x06d20, 0x0ada0,
            0x14b63, 0x09370, 0x049f8, 0x04970, 0x064b0, 0x168a6, 0x0ea50, 0x06b20, 0x1a6c4, 0x0aae0,
            0x0a2e0, 0x0d2e3, 0x0c960, 0x0d557, 0x0d4a0, 0x0da50, 0x05d55, 0x056a0, 0x0a6d0, 0x055d4,
            0x052d0, 0x0a9b8, 0x0a950, 0x0b4a0, 0x0b6a6, 0x0ad50, 0x055a0, 0x0aba4, 0x0a5b0, 0x052b0,
            0x0b273, 0x06930, 0x07337, 0x06aa0, 0x0ad50, 0x14b55, 0x04b60, 0x0a570, 0x054e4, 0x0d160,
            0x0e968, 0x0d520, 0x0daa0, 0x16aa6, 0x056d0, 0x04ae0, 0x0a9d4, 0x0a2d0, 0x0d150, 0x0f252
        )

        try {
            val year = calendar.get(java.util.Calendar.YEAR)
            val month = calendar.get(java.util.Calendar.MONTH) + 1
            val day = calendar.get(java.util.Calendar.DAY_OF_MONTH)

            // Calculate days from base date (1900-01-31 is lunar 1900-01-01)
            val baseCalendar = java.util.Calendar.getInstance()
            baseCalendar.set(1900, 0, 31) // Jan 31, 1900

            val offset = ((calendar.timeInMillis - baseCalendar.timeInMillis) / 86400000).toInt()

            var lunarYear = 1900
            var lunarMonth = 1
            var lunarDay = 1

            var daysRemaining = offset

            // Calculate lunar year
            var yearDays: Int
            while (lunarYear < 2100 && daysRemaining > 0) {
                yearDays = getLunarYearDays(lunarInfo, lunarYear - 1900)
                if (daysRemaining < yearDays) break
                daysRemaining -= yearDays
                lunarYear++
            }

            // Calculate lunar month
            val leapMonth = getLeapMonth(lunarInfo, lunarYear - 1900)
            var isLeap = false
            var monthDays: Int

            for (i in 1..12) {
                if (leapMonth > 0 && i == leapMonth + 1 && !isLeap) {
                    isLeap = true
                    monthDays = getLeapDays(lunarInfo, lunarYear - 1900)
                } else {
                    monthDays = getLunarMonthDays(lunarInfo, lunarYear - 1900, i)
                    if (isLeap) isLeap = false
                }

                if (daysRemaining < monthDays) {
                    lunarMonth = i
                    break
                }
                daysRemaining -= monthDays
            }

            lunarDay = daysRemaining + 1

            // Return lunar day string
            return if (lunarDay <= 30) lunarDays[lunarDay - 1] else "三十"
        } catch (e: Exception) {
            Log.e(TAG, "Error calculating lunar date", e)
            return "初一"
        }
    }

    private fun getLunarYearDays(lunarInfo: IntArray, index: Int): Int {
        if (index < 0 || index >= lunarInfo.size) return 365
        var sum = 348
        var i = 0x8000
        while (i > 0x8) {
            sum += if ((lunarInfo[index] and i) != 0) 1 else 0
            i = i shr 1
        }
        return sum + getLeapDays(lunarInfo, index)
    }

    private fun getLeapMonth(lunarInfo: IntArray, index: Int): Int {
        if (index < 0 || index >= lunarInfo.size) return 0
        return lunarInfo[index] and 0xf
    }

    private fun getLeapDays(lunarInfo: IntArray, index: Int): Int {
        if (getLeapMonth(lunarInfo, index) == 0) return 0
        return if ((lunarInfo[index] and 0x10000) != 0) 30 else 29
    }

    private fun getLunarMonthDays(lunarInfo: IntArray, index: Int, month: Int): Int {
        if (index < 0 || index >= lunarInfo.size) return 30
        return if ((lunarInfo[index] and (0x10000 shr month)) != 0) 30 else 29
    }

    /**
     * Widget skin configuration
     * Contains background drawable resource and text colors for each skin
     * Used by Small, Medium, and Large widgets
     */
    protected data class WidgetSkinConfig(
        val backgroundRes: Int,
        val headerBackgroundRes: Int,  // For Large widget header
        val textColor: Int,
        val secondaryTextColor: Int,
        val headerTextColor: Int,      // For header title (white on colored background)
        val dividerColor: Int,         // For Medium widget divider
        val mediumPriorityIconRes: Int, // Medium priority flag icon (avoids clash with background)
        val backgroundImageRes: Int = 0, // Resource ID for Small widget image background (0 = none)
        val backgroundImageMediumRes: Int = 0, // Resource ID for Medium widget (4x2 ratio)
        val backgroundImageLargeRes: Int = 0   // Resource ID for Large widget (1:1 ratio)
    )

    /**
     * Load "tap text to complete" setting from SharedPreferences
     * Returns true (default) if setting not found
     */
    protected fun loadTapTextToComplete(context: Context): Boolean {
        return try {
            val prefs = HomeWidgetPlugin.getData(context)
            // SharedPreferences 的 getBoolean 默认返回 true
            prefs.getBoolean(KEY_TAP_TEXT_TO_COMPLETE, true)
        } catch (e: Exception) {
            Log.e(TAG, "Error loading tap text setting", e)
            true // 默认开启
        }
    }

    /**
     * Load Widget skin configuration from SharedPreferences
     * Returns default white skin if no setting found
     * Used by all widget sizes (Small, Medium, Large)
     */
    protected fun loadWidgetSkin(context: Context): WidgetSkinConfig {
        return try {
            val prefs = HomeWidgetPlugin.getData(context)
            val skinName = prefs.getString(KEY_SMALL_WIDGET_SKIN, "white") ?: "white"

            when (skinName) {
                "amber" -> WidgetSkinConfig(
                    // 琥珀橙 - 活力品牌色
                    backgroundRes = R.drawable.widget_small_background,
                    headerBackgroundRes = R.drawable.widget_header_background,
                    textColor = Color.parseColor("#4E342E"),       // 深棕色文字
                    secondaryTextColor = Color.parseColor("#6D4C41"), // 中棕色
                    headerTextColor = Color.parseColor("#FFFFFF"),
                    dividerColor = Color.parseColor("#FFAB40"),    // 活力橙分隔线
                    mediumPriorityIconRes = R.drawable.ic_flag_medium_amber,  // 深红色（避免与橙色背景撞色）
                    backgroundImageRes = 0
                )
                "white" -> WidgetSkinConfig(
                    backgroundRes = R.drawable.widget_small_bg_white,
                    headerBackgroundRes = R.drawable.widget_small_bg_white,
                    textColor = Color.parseColor("#212121"),
                    secondaryTextColor = Color.parseColor("#757575"),
                    headerTextColor = Color.parseColor("#212121"),
                    dividerColor = Color.parseColor("#E0E0E0"),
                    mediumPriorityIconRes = R.drawable.ic_flag_medium,  // 标准橙色
                    backgroundImageRes = 0
                )
                "dark" -> WidgetSkinConfig(
                    backgroundRes = R.drawable.widget_small_bg_dark,
                    headerBackgroundRes = R.drawable.widget_small_bg_dark,
                    textColor = Color.parseColor("#E0E0E0"),
                    secondaryTextColor = Color.parseColor("#9E9E9E"),
                    headerTextColor = Color.parseColor("#FFFFFF"),
                    dividerColor = Color.parseColor("#616161"),
                    mediumPriorityIconRes = R.drawable.ic_flag_medium,  // 标准橙色
                    backgroundImageRes = 0
                )
                "mint" -> WidgetSkinConfig(
                    backgroundRes = R.drawable.widget_small_bg_mint,
                    headerBackgroundRes = R.drawable.widget_small_bg_mint,
                    textColor = Color.parseColor("#1B3B38"),
                    secondaryTextColor = Color.parseColor("#2E5752"),
                    headerTextColor = Color.parseColor("#FFFFFF"),
                    dividerColor = Color.parseColor("#4DB6AC"),
                    mediumPriorityIconRes = R.drawable.ic_flag_medium,  // 标准橙色
                    backgroundImageRes = 0
                )
                "pink" -> WidgetSkinConfig(
                    backgroundRes = R.drawable.widget_small_bg_pink,
                    headerBackgroundRes = R.drawable.widget_small_bg_pink,
                    textColor = Color.parseColor("#2D0A1A"),
                    secondaryTextColor = Color.parseColor("#4A1228"),
                    headerTextColor = Color.parseColor("#FFFFFF"),
                    dividerColor = Color.parseColor("#F48FB1"),
                    mediumPriorityIconRes = R.drawable.ic_flag_medium,  // 标准橙色
                    backgroundImageRes = 0
                )
                // 撞色01：雪青/水红（紫粉水墨渐变）- 浅色背景需深色文字
                "contrast01" -> WidgetSkinConfig(
                    backgroundRes = R.drawable.widget_small_background, // Fallback/Underlay
                    headerBackgroundRes = R.drawable.widget_header_background,
                    textColor = Color.parseColor("#4A3B5C"),         // 深紫色文字
                    secondaryTextColor = Color.parseColor("#6B5A7A"), // 中紫色
                    headerTextColor = Color.parseColor("#4A3B5C"),
                    dividerColor = Color.parseColor("#8A7A9A"),
                    mediumPriorityIconRes = R.drawable.ic_flag_medium,  // 标准橙色
                    backgroundImageRes = R.drawable.widget_skin_contrast_01,
                    backgroundImageMediumRes = R.drawable.widget_skin_contrast_01_medium,
                    backgroundImageLargeRes = R.drawable.widget_skin_contrast_01_large
                )
                // 撞色02：浅天蓝/绿萝纱（蓝绿水墨渐变）- 浅色背景需深色文字
                "contrast02" -> WidgetSkinConfig(
                    backgroundRes = R.drawable.widget_small_background,
                    headerBackgroundRes = R.drawable.widget_header_background,
                    textColor = Color.parseColor("#2A4A4A"),         // 深青色文字
                    secondaryTextColor = Color.parseColor("#4A6A6A"), // 中青色
                    headerTextColor = Color.parseColor("#2A4A4A"),
                    dividerColor = Color.parseColor("#6A8A8A"),
                    mediumPriorityIconRes = R.drawable.ic_flag_medium,
                    backgroundImageRes = R.drawable.widget_skin_contrast_02,
                    backgroundImageMediumRes = R.drawable.widget_skin_contrast_02_medium,
                    backgroundImageLargeRes = R.drawable.widget_skin_contrast_02_large
                )
                // 撞色03：柔雾蓝/群青（蓝色水墨渐变）- 浅色背景需深色文字
                "contrast03" -> WidgetSkinConfig(
                    backgroundRes = R.drawable.widget_small_background,
                    headerBackgroundRes = R.drawable.widget_header_background,
                    textColor = Color.parseColor("#1A3A5A"),         // 深蓝色文字
                    secondaryTextColor = Color.parseColor("#3A5A7A"), // 中蓝色
                    headerTextColor = Color.parseColor("#1A3A5A"),
                    dividerColor = Color.parseColor("#5A7A9A"),
                    mediumPriorityIconRes = R.drawable.ic_flag_medium,
                    backgroundImageRes = R.drawable.widget_skin_contrast_03,
                    backgroundImageMediumRes = R.drawable.widget_skin_contrast_03_medium,
                    backgroundImageLargeRes = R.drawable.widget_skin_contrast_03_large
                )
                // 撞色04：远天蓝/天水碧（青蓝水墨渐变）- 浅色背景需深色文字
                "contrast04" -> WidgetSkinConfig(
                    backgroundRes = R.drawable.widget_small_background,
                    headerBackgroundRes = R.drawable.widget_header_background,
                    textColor = Color.parseColor("#1A4A5A"),         // 深青蓝色文字
                    secondaryTextColor = Color.parseColor("#3A6A7A"), // 中青蓝色
                    headerTextColor = Color.parseColor("#1A4A5A"),
                    dividerColor = Color.parseColor("#5A8A9A"),
                    mediumPriorityIconRes = R.drawable.ic_flag_medium,
                    backgroundImageRes = R.drawable.widget_skin_contrast_04,
                    backgroundImageMediumRes = R.drawable.widget_skin_contrast_04_medium,
                    backgroundImageLargeRes = R.drawable.widget_skin_contrast_04_large
                )
                // 撞色05：晴山/盈盈（蓝紫粉水墨渐变）- 浅色背景需深色文字
                "contrast05" -> WidgetSkinConfig(
                    backgroundRes = R.drawable.widget_small_background,
                    headerBackgroundRes = R.drawable.widget_header_background,
                    textColor = Color.parseColor("#3A3A5C"),         // 深蓝紫色文字
                    secondaryTextColor = Color.parseColor("#5A5A7C"), // 中蓝紫色
                    headerTextColor = Color.parseColor("#3A3A5C"),
                    dividerColor = Color.parseColor("#7A7A9C"),
                    mediumPriorityIconRes = R.drawable.ic_flag_medium,
                    backgroundImageRes = R.drawable.widget_skin_contrast_05,
                    backgroundImageMediumRes = R.drawable.widget_skin_contrast_05_medium,
                    backgroundImageLargeRes = R.drawable.widget_skin_contrast_05_large
                )
                else -> WidgetSkinConfig(
                    // Default white skin
                    backgroundRes = R.drawable.widget_small_bg_white,
                    headerBackgroundRes = R.drawable.widget_small_bg_white,
                    textColor = Color.parseColor("#212121"),
                    secondaryTextColor = Color.parseColor("#757575"),
                    headerTextColor = Color.parseColor("#212121"),
                    dividerColor = Color.parseColor("#E0E0E0"),
                    mediumPriorityIconRes = R.drawable.ic_flag_medium,  // 标准橙色
                    backgroundImageRes = 0
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error loading skin config", e)
            // Return default amber orange skin on error
            WidgetSkinConfig(
                backgroundRes = R.drawable.widget_small_background,
                headerBackgroundRes = R.drawable.widget_header_background,
                textColor = Color.parseColor("#4E342E"),
                secondaryTextColor = Color.parseColor("#6D4C41"),
                headerTextColor = Color.parseColor("#FFFFFF"),
                dividerColor = Color.parseColor("#FFAB40"),
                mediumPriorityIconRes = R.drawable.ic_flag_medium_amber,
                backgroundImageRes = 0
            )
        }
    }

    /**
     * Create a bitmap with rounded corners using centerCrop scaling.
     *
     * This approach:
     * 1. Uses centerCrop to scale the image (maintains aspect ratio, fills target area)
     * 2. Applies fixed corner radius via code (corners stay circular regardless of widget size)
     *
     * This ensures corners look good even when widget is resized by dragging.
     *
     * @param context Android context
     * @param resId Drawable resource ID
     * @param targetWidth Target width in pixels (0 = use original)
     * @param targetHeight Target height in pixels (0 = use original)
     * @return Bitmap with rounded corners, or null if failed
     */
    private fun getScaledBitmap(
        context: Context,
        resId: Int,
        targetWidth: Int = 0,
        targetHeight: Int = 0
    ): Bitmap? {
        return try {
            // First, get image dimensions without loading full bitmap
            val options = BitmapFactory.Options().apply {
                inJustDecodeBounds = true
            }
            BitmapFactory.decodeResource(context.resources, resId, options)

            // Determine final output size
            val outputWidth = if (targetWidth > 0) targetWidth else options.outWidth
            val outputHeight = if (targetHeight > 0) targetHeight else options.outHeight

            // Calculate sample size based on target size to reduce memory usage
            val maxDimension = maxOf(outputWidth, outputHeight)
            var sampleSize = 1
            if (options.outWidth > maxDimension * 2 || options.outHeight > maxDimension * 2) {
                val halfWidth = options.outWidth / 2
                val halfHeight = options.outHeight / 2
                while ((halfWidth / sampleSize) >= maxDimension && (halfHeight / sampleSize) >= maxDimension) {
                    sampleSize *= 2
                }
            }

            // Decode with sample size
            val decodeOptions = BitmapFactory.Options().apply {
                inSampleSize = sampleSize
                inPreferredConfig = Bitmap.Config.ARGB_8888
            }
            val original = BitmapFactory.decodeResource(context.resources, resId, decodeOptions)
                ?: return null

            Log.d(TAG, "Loaded skin bitmap: ${original.width}x${original.height} -> target: ${outputWidth}x${outputHeight}")

            // Create output bitmap at target size
            val output = Bitmap.createBitmap(outputWidth, outputHeight, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(output)

            // Fixed corner radius: 20dp converted to pixels (smaller for cleaner look)
            val density = context.resources.displayMetrics.density
            val cornerRadius = 20f * density

            // Paint with full anti-aliasing for smooth corners
            val paint = Paint().apply {
                isAntiAlias = true
                isFilterBitmap = true
                isDither = true
            }

            // Draw rounded rect first as mask
            val rect = RectF(0f, 0f, outputWidth.toFloat(), outputHeight.toFloat())
            canvas.drawRoundRect(rect, cornerRadius, cornerRadius, paint)

            // Set xfermode to clip the source image
            paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)

            // Calculate centerCrop transformation
            // centerCrop: scale to fill, crop excess (maintains aspect ratio)
            val scaleX = outputWidth.toFloat() / original.width
            val scaleY = outputHeight.toFloat() / original.height
            val scale = maxOf(scaleX, scaleY) // Use max to ensure full coverage

            val scaledWidth = original.width * scale
            val scaledHeight = original.height * scale
            val offsetX = (outputWidth - scaledWidth) / 2f
            val offsetY = (outputHeight - scaledHeight) / 2f

            val matrix = Matrix().apply {
                setScale(scale, scale)
                postTranslate(offsetX, offsetY)
            }

            // Draw the original bitmap with centerCrop transformation (clipped by rounded rect)
            canvas.drawBitmap(original, matrix, paint)

            // Clean up original bitmap
            original.recycle()

            output
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create rounded corner bitmap: ${e.message}")
            e.printStackTrace()
            null
        }
    }
}
