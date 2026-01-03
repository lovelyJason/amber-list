#ifndef RUNNER_STICKY_NOTE_MANAGER_H_
#define RUNNER_STICKY_NOTE_MANAGER_H_

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/flutter_engine.h>

#include <map>
#include <memory>
#include <string>

#include "sticky_note_window.h"

// Sticky note window manager (singleton)
// Manages lifecycle of all native sticky note windows
// Handles Platform Channel message dispatching
class StickyNoteManager {
public:
    // Get singleton instance
    static StickyNoteManager& GetInstance();

    // Disable copy and move
    StickyNoteManager(const StickyNoteManager&) = delete;
    StickyNoteManager& operator=(const StickyNoteManager&) = delete;

    // Initialize Platform Channel
    // @param engine Flutter engine
    void Setup(flutter::FlutterEngine* engine);

    // Close all sticky note windows
    void CloseAllWindows();

private:
    StickyNoteManager() = default;
    ~StickyNoteManager();

    // ===== Method Channel handlers =====

    // Handle method calls from Flutter
    void HandleMethodCall(
        const flutter::MethodCall<flutter::EncodableValue>& call,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    // Create sticky note window
    void HandleCreateStickyNote(
        const flutter::EncodableMap& args,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    // Close sticky note window
    void HandleCloseStickyNote(
        const flutter::EncodableMap& args,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    // Update sticky note content
    void HandleUpdateStickyNote(
        const flutter::EncodableMap& args,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    // Focus sticky note window
    void HandleFocusStickyNote(
        const flutter::EncodableMap& args,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    // Check if window is open
    void HandleIsWindowOpen(
        const flutter::EncodableMap& args,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    // ===== Notify Flutter =====

    // Notify Flutter of task status change
    void NotifyTaskToggled(const std::wstring& taskId, bool isCompleted);

    // Notify Flutter of window close
    void NotifyWindowClosed(const std::wstring& noteId);

    // ===== Helper functions =====

    // Wide string to UTF-8
    static std::string WStringToUtf8(const std::wstring& wstr);

    // UTF-8 to wide string
    static std::wstring Utf8ToWString(const std::string& str);

    // Parse hex color string to COLORREF
    static COLORREF ParseColorHex(const std::string& hex);

    // Parse task list
    static std::vector<TaskItem> ParseTaskList(const flutter::EncodableList& list);

    // ===== Member variables =====

    // Platform Channel
    std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> method_channel_;

    // Store all active sticky note windows
    // Key: noteId (wstring), Value: StickyNoteWindow
    std::map<std::wstring, std::unique_ptr<StickyNoteWindow>> window_controllers_;
};

#endif  // RUNNER_STICKY_NOTE_MANAGER_H_