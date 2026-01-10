//
//  WidgetSettingsHelper.swift
//  AmberWidget
//
//  Widget Settings Helper
//
//  Reads and writes task management settings from Flutter's shared storage.
//  This allows the Widget to share the same auto-postpone state as the Flutter app.
//
//  Storage location: App Group UserDefaults
//  Key: task_management_settings
//  Value: JSON object with fields:
//    - enableAutoPostpone: boolean (default true)
//    - overdueExpanded: boolean (default true)
//    - lastAutoPostponeDate: string "yyyy-MM-dd HH:mm:ss" (nullable)
//

import Foundation

/// Widget Settings Helper
/// Manages auto-postpone settings shared between Flutter App and iOS Widget
class WidgetSettingsHelper {

    // MARK: - Constants

    /// App Group ID (must match Flutter HomeWidgetService and Xcode config)
    private static let appGroupID = "group.com.amberlist.amberList"

    /// Settings key in UserDefaults
    private static let settingsKey = "task_management_settings"

    // MARK: - UserDefaults Access

    /// Get shared UserDefaults for App Group
    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    /// Load settings JSON from UserDefaults
    private static func loadSettingsJson() -> [String: Any]? {
        guard let defaults = sharedDefaults,
              let jsonString = defaults.string(forKey: settingsKey),
              !jsonString.isEmpty else {
            return nil
        }

        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            print("[WidgetSettings] Failed to parse settings JSON")
            return nil
        }

        return json
    }

    /// Save settings JSON to UserDefaults
    private static func saveSettingsJson(_ json: [String: Any]) {
        guard let defaults = sharedDefaults else {
            print("[WidgetSettings] Cannot access shared UserDefaults")
            return
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: json),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("[WidgetSettings] Failed to serialize settings JSON")
            return
        }

        defaults.set(jsonString, forKey: settingsKey)
    }

    // MARK: - Auto-Postpone Settings

    /// Check if auto-postpone has been performed today
    ///
    /// Compares the date part (yyyy-MM-dd) of lastAutoPostponeDate with today's date.
    /// Returns true if they match, meaning auto-postpone was already done today.
    ///
    /// - Returns: true if already checked today, false otherwise
    static func hasCheckedToday() -> Bool {
        guard let json = loadSettingsJson(),
              let lastDate = json["lastAutoPostponeDate"] as? String,
              !lastDate.isEmpty else {
            print("[WidgetSettings] hasCheckedToday: no lastAutoPostponeDate found")
            return false
        }

        // Compare date part only (first 10 chars: yyyy-MM-dd)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())

        let lastDatePart = lastDate.count >= 10 ? String(lastDate.prefix(10)) : lastDate
        let checked = lastDatePart == today

        print("[WidgetSettings] hasCheckedToday: \(checked) (lastDate=\(lastDatePart), today=\(today))")
        return checked
    }

    /// Mark today as checked (auto-postpone has been performed)
    ///
    /// Updates lastAutoPostponeDate to current datetime in "yyyy-MM-dd HH:mm:ss" format.
    /// Preserves other settings in the JSON.
    static func setCheckedToday() {
        var json = loadSettingsJson() ?? [:]

        // Update lastAutoPostponeDate
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let now = formatter.string(from: Date())

        json["lastAutoPostponeDate"] = now

        saveSettingsJson(json)
        print("[WidgetSettings] setCheckedToday: \(now)")
    }

    /// Check if auto-postpone feature is enabled globally
    ///
    /// Reads enableAutoPostpone from settings. Defaults to true if not set.
    ///
    /// - Returns: true if auto-postpone is enabled, false otherwise
    static func isAutoPostponeEnabled() -> Bool {
        guard let json = loadSettingsJson() else {
            // Default enabled if no settings found
            return true
        }

        // Default to true if key not present
        let enabled = json["enableAutoPostpone"] as? Bool ?? true
        print("[WidgetSettings] isAutoPostponeEnabled: \(enabled)")
        return enabled
    }

    // MARK: - Debug

    /// Get last auto-postpone check date (for debugging)
    ///
    /// - Returns: lastAutoPostponeDate string or nil
    static func getLastCheckDate() -> String? {
        guard let json = loadSettingsJson(),
              let lastDate = json["lastAutoPostponeDate"] as? String else {
            return nil
        }
        return lastDate
    }
}
