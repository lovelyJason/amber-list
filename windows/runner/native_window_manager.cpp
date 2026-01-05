#include "native_window_manager.h"
#include "quick_add_window.h"
#include <iostream>
#include <windows.h>

NativeWindowManager& NativeWindowManager::GetInstance() {
    static NativeWindowManager instance;
    return instance;
}

NativeWindowManager::~NativeWindowManager() {
    CloseAllWindows();
}

void NativeWindowManager::Setup(flutter::FlutterEngine* engine) {
    method_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        engine->messenger(),
        "com.amberlist.native_window",
        &flutter::StandardMethodCodec::GetInstance()
    );

    method_channel_->SetMethodCallHandler(
        [this](const flutter::MethodCall<flutter::EncodableValue>& call,
               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
            HandleMethodCall(call, std::move(result));
        }
    );

    // 注册内置窗口工厂
    RegisterBuiltInFactories();

    std::cout << "[NativeWindowManager] Platform Channel registered: com.amberlist.native_window" << std::endl;
}

void NativeWindowManager::RegisterBuiltInFactories() {
    // 注册 QuickAdd 窗口工厂
    RegisterFactory("quick_add", [](const std::wstring& windowId, const flutter::EncodableMap* arguments) {
        return std::make_unique<QuickAddWindow>(windowId, arguments);
    });

    std::cout << "[NativeWindowManager] Built-in factories registered: quick_add" << std::endl;
}

void NativeWindowManager::RegisterFactory(const std::string& windowType, WindowFactory factory) {
    factories_[windowType] = std::move(factory);
}

void NativeWindowManager::CloseAllWindows() {
    for (auto& pair : windows_) {
        if (pair.second) {
            pair.second->Destroy();
        }
    }
    windows_.clear();
    std::cout << "[NativeWindowManager] All windows closed" << std::endl;
}

void NativeWindowManager::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

    const std::string& method = call.method_name();

    // 不需要参数的方法优先处理
    if (method == "getOpenWindows") {
        HandleGetOpenWindows(std::move(result));
        return;
    }

    // 获取参数（其他方法需要参数）
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!args) {
        result->Error("INVALID_ARGS", "Arguments must be a map");
        return;
    }

    if (method == "createOrShow") {
        HandleCreateOrShow(*args, std::move(result));
    } else if (method == "hide") {
        HandleHide(*args, std::move(result));
    } else if (method == "destroy") {
        HandleDestroy(*args, std::move(result));
    } else if (method == "sendMessage") {
        HandleSendMessage(*args, std::move(result));
    } else if (method == "isWindowOpen") {
        HandleIsWindowOpen(*args, std::move(result));
    } else {
        result->NotImplemented();
    }
}

void NativeWindowManager::HandleCreateOrShow(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

    // 解析 windowType
    auto typeIt = args.find(flutter::EncodableValue("windowType"));
    if (typeIt == args.end()) {
        result->Error("INVALID_ARGS", "Missing windowType");
        return;
    }
    std::string windowType = std::get<std::string>(typeIt->second);

    // 解析 windowId（可选）
    std::wstring windowId;
    auto idIt = args.find(flutter::EncodableValue("windowId"));
    if (idIt != args.end() && !std::holds_alternative<std::monostate>(idIt->second)) {
        windowId = Utf8ToWString(std::get<std::string>(idIt->second));
    }

    // 解析 arguments（可选）
    const flutter::EncodableMap* showArgs = nullptr;
    auto argsIt = args.find(flutter::EncodableValue("arguments"));
    if (argsIt != args.end()) {
        showArgs = std::get_if<flutter::EncodableMap>(&argsIt->second);
    }

    // 生成窗口标识符
    std::string identifier = MakeIdentifier(windowType, windowId);

    // 如果窗口已存在，直接显示
    auto existingIt = windows_.find(identifier);
    if (existingIt != windows_.end() && existingIt->second) {
        existingIt->second->Show(showArgs);

        flutter::EncodableMap response;
        response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
        response[flutter::EncodableValue("identifier")] = flutter::EncodableValue(identifier);
        response[flutter::EncodableValue("created")] = flutter::EncodableValue(false);
        result->Success(flutter::EncodableValue(response));
        return;
    }

    // 查找工厂创建新窗口
    auto factoryIt = factories_.find(windowType);
    if (factoryIt == factories_.end()) {
        result->Error("UNKNOWN_TYPE", "No factory registered for window type: " + windowType);
        return;
    }

    // 创建窗口
    auto window = factoryIt->second(windowId, showArgs);
    if (!window) {
        result->Error("CREATE_FAILED", "Failed to create window");
        return;
    }

    // 显示窗口
    window->Show(showArgs);

    // 存储窗口
    windows_[identifier] = std::move(window);

    std::cout << "[NativeWindowManager] Created window: " << identifier << std::endl;

    flutter::EncodableMap response;
    response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
    response[flutter::EncodableValue("identifier")] = flutter::EncodableValue(identifier);
    response[flutter::EncodableValue("created")] = flutter::EncodableValue(true);
    result->Success(flutter::EncodableValue(response));
}

void NativeWindowManager::HandleHide(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

    // 解析 windowType
    auto typeIt = args.find(flutter::EncodableValue("windowType"));
    if (typeIt == args.end()) {
        result->Error("INVALID_ARGS", "Missing windowType");
        return;
    }
    std::string windowType = std::get<std::string>(typeIt->second);

    // 解析 windowId（可选）
    std::wstring windowId;
    auto idIt = args.find(flutter::EncodableValue("windowId"));
    if (idIt != args.end() && !std::holds_alternative<std::monostate>(idIt->second)) {
        windowId = Utf8ToWString(std::get<std::string>(idIt->second));
    }

    std::string identifier = MakeIdentifier(windowType, windowId);

    auto it = windows_.find(identifier);
    if (it != windows_.end() && it->second) {
        it->second->Hide();

        flutter::EncodableMap response;
        response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
        result->Success(flutter::EncodableValue(response));
    } else {
        flutter::EncodableMap response;
        response[flutter::EncodableValue("success")] = flutter::EncodableValue(false);
        response[flutter::EncodableValue("error")] = flutter::EncodableValue("Window not found: " + identifier);
        result->Success(flutter::EncodableValue(response));
    }
}

void NativeWindowManager::HandleDestroy(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

    // 解析 windowType
    auto typeIt = args.find(flutter::EncodableValue("windowType"));
    if (typeIt == args.end()) {
        result->Error("INVALID_ARGS", "Missing windowType");
        return;
    }
    std::string windowType = std::get<std::string>(typeIt->second);

    // 解析 windowId（可选）
    std::wstring windowId;
    auto idIt = args.find(flutter::EncodableValue("windowId"));
    if (idIt != args.end() && !std::holds_alternative<std::monostate>(idIt->second)) {
        windowId = Utf8ToWString(std::get<std::string>(idIt->second));
    }

    std::string identifier = MakeIdentifier(windowType, windowId);

    auto it = windows_.find(identifier);
    if (it != windows_.end() && it->second) {
        it->second->Destroy();
        windows_.erase(it);

        std::cout << "[NativeWindowManager] Destroyed window: " << identifier << std::endl;

        flutter::EncodableMap response;
        response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
        result->Success(flutter::EncodableValue(response));
    } else {
        flutter::EncodableMap response;
        response[flutter::EncodableValue("success")] = flutter::EncodableValue(false);
        response[flutter::EncodableValue("error")] = flutter::EncodableValue("Window not found: " + identifier);
        result->Success(flutter::EncodableValue(response));
    }
}

void NativeWindowManager::HandleSendMessage(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

    // 解析 windowType
    auto typeIt = args.find(flutter::EncodableValue("windowType"));
    if (typeIt == args.end()) {
        result->Error("INVALID_ARGS", "Missing windowType");
        return;
    }
    std::string windowType = std::get<std::string>(typeIt->second);

    // 解析 method
    auto methodIt = args.find(flutter::EncodableValue("method"));
    if (methodIt == args.end()) {
        result->Error("INVALID_ARGS", "Missing method");
        return;
    }
    std::string method = std::get<std::string>(methodIt->second);

    // 解析 windowId（可选）
    std::wstring windowId;
    auto idIt = args.find(flutter::EncodableValue("windowId"));
    if (idIt != args.end() && !std::holds_alternative<std::monostate>(idIt->second)) {
        windowId = Utf8ToWString(std::get<std::string>(idIt->second));
    }

    // 解析 arguments（可选）
    const flutter::EncodableValue* messageArgs = nullptr;
    auto argsIt = args.find(flutter::EncodableValue("arguments"));
    if (argsIt != args.end()) {
        messageArgs = &argsIt->second;
    }

    std::string identifier = MakeIdentifier(windowType, windowId);

    auto it = windows_.find(identifier);
    if (it != windows_.end() && it->second) {
        it->second->HandleFlutterMessage(method, messageArgs, std::move(result));
    } else {
        result->Error("NOT_FOUND", "Window not found: " + identifier);
    }
}

void NativeWindowManager::HandleIsWindowOpen(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

    // 解析 windowType
    auto typeIt = args.find(flutter::EncodableValue("windowType"));
    if (typeIt == args.end()) {
        result->Error("INVALID_ARGS", "Missing windowType");
        return;
    }
    std::string windowType = std::get<std::string>(typeIt->second);

    // 解析 windowId（可选）
    std::wstring windowId;
    auto idIt = args.find(flutter::EncodableValue("windowId"));
    if (idIt != args.end() && !std::holds_alternative<std::monostate>(idIt->second)) {
        windowId = Utf8ToWString(std::get<std::string>(idIt->second));
    }

    std::string identifier = MakeIdentifier(windowType, windowId);
    bool isOpen = windows_.find(identifier) != windows_.end();

    flutter::EncodableMap response;
    response[flutter::EncodableValue("isOpen")] = flutter::EncodableValue(isOpen);
    response[flutter::EncodableValue("identifier")] = flutter::EncodableValue(identifier);
    result->Success(flutter::EncodableValue(response));
}

void NativeWindowManager::HandleGetOpenWindows(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

    flutter::EncodableList windowsList;
    for (const auto& pair : windows_) {
        windowsList.push_back(flutter::EncodableValue(pair.first));
    }

    flutter::EncodableMap response;
    response[flutter::EncodableValue("windows")] = flutter::EncodableValue(windowsList);
    result->Success(flutter::EncodableValue(response));
}

void NativeWindowManager::NotifyFlutter(const std::string& method, const flutter::EncodableMap& arguments) {
    if (!method_channel_) return;

    method_channel_->InvokeMethod(method, std::make_unique<flutter::EncodableValue>(arguments));

    std::cout << "[NativeWindowManager] Notify Flutter: " << method << std::endl;
}

void NativeWindowManager::WindowDidClose(const std::string& windowType, const std::wstring& windowId) {
    std::string identifier = MakeIdentifier(windowType, windowId);
    windows_.erase(identifier);

    flutter::EncodableMap args;
    args[flutter::EncodableValue("windowType")] = flutter::EncodableValue(windowType);
    if (!windowId.empty()) {
        args[flutter::EncodableValue("windowId")] = flutter::EncodableValue(WStringToUtf8(windowId));
    }
    args[flutter::EncodableValue("identifier")] = flutter::EncodableValue(identifier);

    NotifyFlutter("onWindowClosed", args);

    std::cout << "[NativeWindowManager] Window closed: " << identifier << std::endl;
}

std::string NativeWindowManager::MakeIdentifier(const std::string& windowType, const std::wstring& windowId) {
    if (windowId.empty()) {
        return windowType;
    }
    return windowType + "_" + WStringToUtf8(windowId);
}

// ===== Helper functions =====

std::string NativeWindowManager::WStringToUtf8(const std::wstring& wstr) {
    if (wstr.empty()) return std::string();

    int sizeNeeded = WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), -1, nullptr, 0, nullptr, nullptr);
    std::string result(sizeNeeded - 1, 0);
    WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), -1, &result[0], sizeNeeded, nullptr, nullptr);
    return result;
}

std::wstring NativeWindowManager::Utf8ToWString(const std::string& str) {
    if (str.empty()) return std::wstring();

    int sizeNeeded = MultiByteToWideChar(CP_UTF8, 0, str.c_str(), -1, nullptr, 0);
    std::wstring result(sizeNeeded - 1, 0);
    MultiByteToWideChar(CP_UTF8, 0, str.c_str(), -1, &result[0], sizeNeeded);
    return result;
}
