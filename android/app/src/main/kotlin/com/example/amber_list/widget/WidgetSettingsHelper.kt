package com.example.amber_list.widget

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Widget Settings Helper
 *
 * Reads and writes task management settings from Flutter's SharedPreferences.
 * This allows the Widget to share the same auto-postpone state as the Flutter app.
 *
 * SharedPreferences file: FlutterSharedPreferences
 * Key: flutter.task_management_settings
 * Value: JSON object with fields:
 *   - enableAutoPostpone: boolean (default true)
 *   - overdueExpanded: boolean (default true)
 *   - lastAutoPostponeDate: string "yyyy-MM-dd HH:mm:ss" (nullable)
 */
object WidgetSettingsHelper {

    private const val TAG = "WidgetSettingsHelper"
    private const val PREFS_NAME = "FlutterSharedPreferences"
    private const val KEY = "flutter.task_management_settings"

    /**
     * Check if auto-postpone has been performed today
     *
     * Compares the date part (yyyy-MM-dd) of lastAutoPostponeDate with today's date.
     * Returns true if they match, meaning auto-postpone was already done today.
     *
     * @param context Application context
     * @return true if already checked today, false otherwise
     */
    fun hasCheckedToday(context: Context): Boolean {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val json = prefs.getString(KEY, null)

            if (json.isNullOrEmpty()) return false

            val obj = JSONObject(json)
            val lastDate = obj.optString("lastAutoPostponeDate", "")
            if (lastDate.isEmpty()) return false

            // Compare date part only (first 10 chars: yyyy-MM-dd)
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
            val lastDatePart = if (lastDate.length >= 10) lastDate.substring(0, 10) else lastDate
            return lastDatePart == today
        } catch (e: Exception) {
            Log.e(TAG, "hasCheckedToday error", e)
            return false
        }
    }

    /**
     * Mark today as checked (auto-postpone has been performed)
     *
     * Updates lastAutoPostponeDate to current datetime in "yyyy-MM-dd HH:mm:ss" format.
     * Preserves other settings in the JSON.
     *
     * @param context Application context
     */
    fun setCheckedToday(context: Context) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val existingJson = prefs.getString(KEY, null)

            // Parse existing or create new JSON object
            val obj = if (!existingJson.isNullOrEmpty()) {
                JSONObject(existingJson)
            } else {
                JSONObject()
            }

            // Update lastAutoPostponeDate
            val now = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date())
            obj.put("lastAutoPostponeDate", now)

            // Save back
            prefs.edit().putString(KEY, obj.toString()).apply()
        } catch (e: Exception) {
            Log.e(TAG, "setCheckedToday error", e)
        }
    }

    /**
     * Check if auto-postpone feature is enabled globally
     *
     * Reads enableAutoPostpone from settings. Defaults to true if not set.
     *
     * @param context Application context
     * @return true if auto-postpone is enabled, false otherwise
     */
    fun isAutoPostponeEnabled(context: Context): Boolean {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val json = prefs.getString(KEY, null)

            if (json.isNullOrEmpty()) return true // Default enabled

            val obj = JSONObject(json)
            return obj.optBoolean("enableAutoPostpone", true)
        } catch (e: Exception) {
            Log.e(TAG, "isAutoPostponeEnabled error", e)
            return true // Default enabled on error
        }
    }
}
