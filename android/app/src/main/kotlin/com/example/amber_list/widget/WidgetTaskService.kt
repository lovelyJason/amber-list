package com.example.amber_list.widget

import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import com.example.amber_list.R

/**
 * RemoteViewsService for Small Widget StackView
 *
 * Provides task items to the StackView for auto-rotation display.
 * Tasks are loaded from SharedPreferences (synced from Flutter).
 */
class WidgetTaskService : RemoteViewsService() {

    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return WidgetTaskFactory(applicationContext)
    }
}

/**
 * RemoteViewsFactory that creates task item views for StackView
 */
class WidgetTaskFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {

    companion object {
        private const val TAG = "WidgetTaskFactory"
        private const val KEY_WIDGET_TASKS = "widget_tasks"
    }

    private var tasks = mutableListOf<TaskItem>()

    data class TaskItem(
        val id: String,
        val title: String
    )

    override fun onCreate() {
        Log.d(TAG, "onCreate")
    }

    override fun onDataSetChanged() {
        Log.d(TAG, "onDataSetChanged")
        loadTasks()
    }

    override fun onDestroy() {
        tasks.clear()
    }

    override fun getCount(): Int = tasks.size

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_task_item)

        if (position < tasks.size) {
            val task = tasks[position]
            views.setTextViewText(R.id.task_title, task.title)
            views.setImageViewResource(R.id.task_checkbox, R.drawable.ic_checkbox_unchecked)
        }

        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true

    /**
     * Load tasks from SharedPreferences
     */
    private fun loadTasks() {
        tasks.clear()

        try {
            val prefs = HomeWidgetPlugin.getData(context)
            val jsonString = prefs.getString(KEY_WIDGET_TASKS, null)

            if (jsonString.isNullOrEmpty()) {
                Log.d(TAG, "No tasks in SharedPreferences")
                return
            }

            val jsonArray = JSONArray(jsonString)
            for (i in 0 until minOf(jsonArray.length(), 6)) {
                val obj = jsonArray.getJSONObject(i)
                val isCompleted = obj.getBoolean("isCompleted")

                // Only show incomplete tasks
                if (!isCompleted) {
                    tasks.add(TaskItem(
                        id = obj.getString("id"),
                        title = obj.getString("title")
                    ))
                }
            }

            Log.d(TAG, "Loaded ${tasks.size} tasks for StackView")
        } catch (e: Exception) {
            Log.e(TAG, "Error loading tasks", e)
        }
    }
}
