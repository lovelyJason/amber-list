#include "sticky_note_manager.h"
#include <iostream>
#include <sstream>
#include <codecvt>
#include <locale>

StickyNoteManager& StickyNoteManager::GetInstance() {
    static StickyNoteManager instance;
    return instance;
}

StickyNoteManager::~StickyNoteManager() {
    CloseAllWindows();
}

void StickyNoteManager::Setup(flutter::FlutterEngine* engine) {
    method_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        engine->messenger(),
        "com.amberlist.sticky_note",
        &flutter::StandardMethodCodec::GetInstance()
    );

    method_channel_->SetMethodCallHandler(
        [this](const flutter::MethodCall<flutter::EncodableValue>& call,
               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
            HandleMethodCall(call, std::move(result));
        }
    );

    std::cout << "[StickyNoteManager] Platform Channel 已注册" << std::endl;
}

void StickyNoteManager::CloseAllWindows() {
    for (auto& pair : window_controllers_) {
        if (pair.second) {
            pair.second->Close();
        }
    }
    window_controllers_.clear();
}

void StickyNoteManager::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

    const std::string& method = call.method_name();

    // 获取参数
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!args && method != "ping") {
        result->Error("INVALID_ARGS", "Arguments must be a map");
        return;
    }

    if (method == "createStickyNote") {
        HandleCreateStickyNote(*args, std::move(result));
    } else if (method == "closeStickyNote") {
        HandleCloseStickyNote(*args, std::move(result));
    } else if (method == "updateStickyNote") {
        HandleUpdateStickyNote(*args, std::move(result));
    } else if (method == "focusStickyNote") {
        HandleFocusStickyNote(*args, std::move(result));
    } else if (method == "isWindowOpen") {
        HandleIsWindowOpen(*args, std::move(result));
    } else {
        result->NotImplemented();
    }
}

void StickyNoteManager::HandleCreateStickyNote(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

    // 解析参数
    auto idIt = args.find(flutter::EncodableValue("id"));
    auto titleIt = args.find(flutter::EncodableValue("title"));

    if (idIt == args.end() || titleIt == args.end()) {
        result->Error("INVALID_ARGS", "Missing required arguments: id, title");
        return;
    }

    std::string noteIdStr = std::get<std::string>(idIt->second);
    std::string titleStr = std::get<std::string>(titleIt->second);
    std::wstring noteId = Utf8ToWString(noteIdStr);
    std::wstring title = Utf8ToWString(titleStr);

    // 如果已存在，聚焦
    auto existingIt = window_controllers_.find(noteId);
    if (existingIt != window_controllers_.end() && existingIt->second) {
        existingIt->second->Focus();
        flutter::EncodableMap response;
        response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
        response[flutter::EncodableValue("windowId")] = flutter::EncodableValue(noteIdStr);
        result->Success(flutter::EncodableValue(response));
        return;
    }

    // 解析主题色
    COLORREF themeColor = RGB(255, 247, 209);  // 默认黄色
    auto colorIt = args.find(flutter::EncodableValue("themeColor"));
    if (colorIt != args.end()) {
        std::string colorHex = std::get<std::string>(colorIt->second);
        themeColor = ParseColorHex(colorHex);
    }

    // 解析任务列表
    std::vector<TaskItem> activeTasks;
    std::vector<TaskItem> completedTasks;

    auto activeIt = args.find(flutter::EncodableValue("active"));
    if (activeIt != args.end()) {
        const auto* activeList = std::get_if<flutter::EncodableList>(&activeIt->second);
        if (activeList) {
            activeTasks = ParseTaskList(*activeList);
        }
    }

    auto completedIt = args.find(flutter::EncodableValue("completed"));
    if (completedIt != args.end()) {
        const auto* completedList = std::get_if<flutter::EncodableList>(&completedIt->second);
        if (completedList) {
            completedTasks = ParseTaskList(*completedList);
        }
    }

    // 创建窗口
    auto window = std::make_unique<StickyNoteWindow>(noteId, title, themeColor);

    // 设置回调
    window->onTaskToggled = [this](const std::wstring& taskId, bool isCompleted) {
        NotifyTaskToggled(taskId, isCompleted);
    };

    window->onWindowClosed = [this](const std::wstring& closedNoteId) {
        window_controllers_.erase(closedNoteId);
        NotifyWindowClosed(closedNoteId);
    };

    // 更新任务
    window->UpdateTasks(activeTasks, completedTasks);

    // 创建并显示
    if (!window->Create()) {
        result->Error("CREATE_FAILED", "Failed to create window");
        return;
    }

    window->Show();

    // 存储
    window_controllers_[noteId] = std::move(window);

    std::cout << "[StickyNoteManager] 创建便签窗口: " << noteIdStr << std::endl;

    flutter::EncodableMap response;
    response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
    response[flutter::EncodableValue("windowId")] = flutter::EncodableValue(noteIdStr);
    result->Success(flutter::EncodableValue(response));
}

void StickyNoteManager::HandleCloseStickyNote(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

    auto idIt = args.find(flutter::EncodableValue("id"));
    if (idIt == args.end()) {
        result->Error("INVALID_ARGS", "Missing note id");
        return;
    }

    std::string noteIdStr = std::get<std::string>(idIt->second);
    std::wstring noteId = Utf8ToWString(noteIdStr);

    auto it = window_controllers_.find(noteId);
    if (it != window_controllers_.end() && it->second) {
        it->second->Close();
        window_controllers_.erase(it);

        flutter::EncodableMap response;
        response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
        result->Success(flutter::EncodableValue(response));
    } else {
        flutter::EncodableMap response;
        response[flutter::EncodableValue("success")] = flutter::EncodableValue(false);
        response[flutter::EncodableValue("error")] = flutter::EncodableValue("Window not found");
        result->Success(flutter::EncodableValue(response));
    }
}

void StickyNoteManager::HandleUpdateStickyNote(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

    auto idIt = args.find(flutter::EncodableValue("id"));
    if (idIt == args.end()) {
        result->Error("INVALID_ARGS", "Missing note id");
        return;
    }

    std::string noteIdStr = std::get<std::string>(idIt->second);
    std::wstring noteId = Utf8ToWString(noteIdStr);

    auto it = window_controllers_.find(noteId);
    if (it == window_controllers_.end() || !it->second) {
        flutter::EncodableMap response;
        response[flutter::EncodableValue("success")] = flutter::EncodableValue(false);
        response[flutter::EncodableValue("error")] = flutter::EncodableValue("Window not found");
        result->Success(flutter::EncodableValue(response));
        return;
    }

    // 解析任务列表
    std::vector<TaskItem> activeTasks;
    std::vector<TaskItem> completedTasks;

    auto activeIt = args.find(flutter::EncodableValue("active"));
    if (activeIt != args.end()) {
        const auto* activeList = std::get_if<flutter::EncodableList>(&activeIt->second);
        if (activeList) {
            activeTasks = ParseTaskList(*activeList);
        }
    }

    auto completedIt = args.find(flutter::EncodableValue("completed"));
    if (completedIt != args.end()) {
        const auto* completedList = std::get_if<flutter::EncodableList>(&completedIt->second);
        if (completedList) {
            completedTasks = ParseTaskList(*completedList);
        }
    }

    it->second->UpdateTasks(activeTasks, completedTasks);

    flutter::EncodableMap response;
    response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
    result->Success(flutter::EncodableValue(response));
}

void StickyNoteManager::HandleFocusStickyNote(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

    auto idIt = args.find(flutter::EncodableValue("id"));
    if (idIt == args.end()) {
        result->Error("INVALID_ARGS", "Missing note id");
        return;
    }

    std::string noteIdStr = std::get<std::string>(idIt->second);
    std::wstring noteId = Utf8ToWString(noteIdStr);

    auto it = window_controllers_.find(noteId);
    if (it != window_controllers_.end() && it->second) {
        it->second->Focus();

        flutter::EncodableMap response;
        response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
        result->Success(flutter::EncodableValue(response));
    } else {
        flutter::EncodableMap response;
        response[flutter::EncodableValue("success")] = flutter::EncodableValue(false);
        response[flutter::EncodableValue("error")] = flutter::EncodableValue("Window not found");
        result->Success(flutter::EncodableValue(response));
    }
}

void StickyNoteManager::HandleIsWindowOpen(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

    auto idIt = args.find(flutter::EncodableValue("id"));
    if (idIt == args.end()) {
        result->Error("INVALID_ARGS", "Missing note id");
        return;
    }

    std::string noteIdStr = std::get<std::string>(idIt->second);
    std::wstring noteId = Utf8ToWString(noteIdStr);

    bool isOpen = window_controllers_.find(noteId) != window_controllers_.end();

    flutter::EncodableMap response;
    response[flutter::EncodableValue("isOpen")] = flutter::EncodableValue(isOpen);
    result->Success(flutter::EncodableValue(response));
}

void StickyNoteManager::NotifyTaskToggled(const std::wstring& taskId, bool isCompleted) {
    if (!method_channel_) return;

    flutter::EncodableMap args;
    args[flutter::EncodableValue("taskId")] = flutter::EncodableValue(WStringToUtf8(taskId));
    args[flutter::EncodableValue("isCompleted")] = flutter::EncodableValue(isCompleted);

    method_channel_->InvokeMethod("onTaskToggled",
                                   std::make_unique<flutter::EncodableValue>(args));

    std::cout << "[StickyNoteManager] 通知 Flutter 任务状态变化: " << WStringToUtf8(taskId)
              << " -> " << (isCompleted ? "completed" : "active") << std::endl;
}

void StickyNoteManager::NotifyWindowClosed(const std::wstring& noteId) {
    if (!method_channel_) return;

    flutter::EncodableMap args;
    args[flutter::EncodableValue("id")] = flutter::EncodableValue(WStringToUtf8(noteId));

    method_channel_->InvokeMethod("onStickyNoteClosed",
                                   std::make_unique<flutter::EncodableValue>(args));

    std::cout << "[StickyNoteManager] 通知 Flutter 窗口关闭: " << WStringToUtf8(noteId) << std::endl;
}

// ===== 辅助函数实现 =====

std::string StickyNoteManager::WStringToUtf8(const std::wstring& wstr) {
    if (wstr.empty()) return std::string();

    int sizeNeeded = WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), -1, nullptr, 0, nullptr, nullptr);
    std::string result(sizeNeeded - 1, 0);
    WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), -1, &result[0], sizeNeeded, nullptr, nullptr);
    return result;
}

std::wstring StickyNoteManager::Utf8ToWString(const std::string& str) {
    if (str.empty()) return std::wstring();

    int sizeNeeded = MultiByteToWideChar(CP_UTF8, 0, str.c_str(), -1, nullptr, 0);
    std::wstring result(sizeNeeded - 1, 0);
    MultiByteToWideChar(CP_UTF8, 0, str.c_str(), -1, &result[0], sizeNeeded);
    return result;
}

COLORREF StickyNoteManager::ParseColorHex(const std::string& hex) {
    // 格式: "0xFFFFF7D1" (ARGB)
    if (hex.length() < 8) {
        return RGB(255, 247, 209);  // 默认黄色
    }

    try {
        // 跳过 "0x" 或 "0xFF" (alpha)
        std::string colorPart = hex;
        if (colorPart.substr(0, 2) == "0x" || colorPart.substr(0, 2) == "0X") {
            colorPart = colorPart.substr(2);
        }
        if (colorPart.length() >= 8) {
            colorPart = colorPart.substr(2);  // 跳过 alpha
        }

        unsigned long value = std::stoul(colorPart, nullptr, 16);
        int r = (value >> 16) & 0xFF;
        int g = (value >> 8) & 0xFF;
        int b = value & 0xFF;
        return RGB(r, g, b);
    } catch (...) {
        return RGB(255, 247, 209);
    }
}

std::vector<TaskItem> StickyNoteManager::ParseTaskList(const flutter::EncodableList& list) {
    std::vector<TaskItem> result;

    for (const auto& item : list) {
        const auto* map = std::get_if<flutter::EncodableMap>(&item);
        if (!map) continue;

        TaskItem task;

        auto idIt = map->find(flutter::EncodableValue("id"));
        if (idIt != map->end()) {
            task.id = Utf8ToWString(std::get<std::string>(idIt->second));
        }

        auto titleIt = map->find(flutter::EncodableValue("title"));
        if (titleIt != map->end()) {
            task.title = Utf8ToWString(std::get<std::string>(titleIt->second));
        }

        auto completedIt = map->find(flutter::EncodableValue("isCompleted"));
        if (completedIt != map->end()) {
            task.isCompleted = std::get<bool>(completedIt->second);
        } else {
            task.isCompleted = false;
        }

        result.push_back(task);
    }

    return result;
}
