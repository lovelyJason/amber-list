#ifndef RUNNER_NATIVE_WINDOW_MANAGER_H_
#define RUNNER_NATIVE_WINDOW_MANAGER_H_

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/flutter_engine.h>

#include <map>
#include <memory>
#include <string>
#include <functional>

// Forward declaration
class NativeWindowBase;

/// Native Window Manager (Windows)
///
/// Manages the lifecycle of all native windows and Platform Channel communication.
/// Supports multiple window types (QuickAdd, StickyNote, etc.) with message routing by window type.
///
/// Design principles:
/// - Single entry point: All native window operations go through this manager
/// - Factory pattern: Windows are created via registered factory functions
/// - Message routing: Flutter messages are dispatched based on windowType
class NativeWindowManager {
public:
    /// Window factory function type
    /// Parameters: windowId, arguments
    /// Returns: Window instance
    using WindowFactory = std::function<std::unique_ptr<NativeWindowBase>(
        const std::wstring& windowId,
        const flutter::EncodableMap* arguments)>;

    /// Get singleton instance
    static NativeWindowManager& GetInstance();

    // Disable copy and move
    NativeWindowManager(const NativeWindowManager&) = delete;
    NativeWindowManager& operator=(const NativeWindowManager&) = delete;

    /// Initialize Platform Channel
    /// @param engine Flutter engine
    void Setup(flutter::FlutterEngine* engine);

    /// Register window factory
    /// @param windowType Window type identifier
    /// @param factory Factory function to create windows
    void RegisterFactory(const std::string& windowType, WindowFactory factory);

    /// Send message to Flutter
    /// @param method Method name
    /// @param arguments Arguments
    void NotifyFlutter(const std::string& method, const flutter::EncodableMap& arguments);

    /// Window close callback (called by windows)
    /// @param windowType Window type
    /// @param windowId Window ID (optional)
    void WindowDidClose(const std::string& windowType, const std::wstring& windowId);

    /// Close all windows
    void CloseAllWindows();

    /// Helper: Wide string to UTF-8
    static std::string WStringToUtf8(const std::wstring& wstr);

    /// Helper: UTF-8 to wide string
    static std::wstring Utf8ToWString(const std::string& str);

private:
    NativeWindowManager() = default;
    ~NativeWindowManager();

    // ===== Method Channel handlers =====

    /// Handle method calls from Flutter
    void HandleMethodCall(
        const flutter::MethodCall<flutter::EncodableValue>& call,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    /// Create or show window
    void HandleCreateOrShow(
        const flutter::EncodableMap& args,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    /// Hide window
    void HandleHide(
        const flutter::EncodableMap& args,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    /// Destroy window
    void HandleDestroy(
        const flutter::EncodableMap& args,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    /// Send message to window
    void HandleSendMessage(
        const flutter::EncodableMap& args,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    /// Check if window is open
    void HandleIsWindowOpen(
        const flutter::EncodableMap& args,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    /// Get all open windows
    void HandleGetOpenWindows(
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    // ===== Helpers =====

    /// Generate window identifier
    std::string MakeIdentifier(const std::string& windowType, const std::wstring& windowId);

    /// Register built-in window factories
    void RegisterBuiltInFactories();

    // ===== Member variables =====

    /// Platform Channel
    std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> method_channel_;

    /// Registry of all active windows
    /// Key: Window identifier (windowType or windowType_windowId)
    std::map<std::string, std::unique_ptr<NativeWindowBase>> windows_;

    /// Registry of window factories
    /// Key: Window type
    std::map<std::string, WindowFactory> factories_;
};

/// Native Window Base Class
///
/// All native windows (QuickAdd, StickyNote, etc.) must inherit from this class.
/// Provides a unified window lifecycle management interface.
class NativeWindowBase {
public:
    virtual ~NativeWindowBase() = default;

    /// Get window type identifier
    virtual std::string GetWindowType() const = 0;

    /// Get window instance ID (optional)
    virtual std::wstring GetWindowId() const { return L""; }

    /// Show window
    /// @param arguments Create/show arguments
    virtual void Show(const flutter::EncodableMap* arguments) = 0;

    /// Hide window (without destroying)
    virtual void Hide() = 0;

    /// Destroy window
    virtual void Destroy() = 0;

    /// Handle messages from Flutter
    /// @param method Method name
    /// @param arguments Arguments
    /// @param result Flutter result callback
    virtual void HandleFlutterMessage(
        const std::string& method,
        const flutter::EncodableValue* arguments,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) = 0;
};

#endif  // RUNNER_NATIVE_WINDOW_MANAGER_H_
