#include "quick_add_window.h"
#include <iostream>
#include <sstream>
#include <iomanip>
#include <ctime>
#include <dwmapi.h>

// 静态成员初始化
const wchar_t* QuickAddWindow::kWindowClassName = L"AmberQuickAddWindow";
bool QuickAddWindow::class_registered_ = false;

QuickAddWindow::QuickAddWindow(const std::wstring& windowId, const flutter::EncodableMap* arguments)
    : window_id_(windowId) {

    // 解析初始参数
    if (arguments) {
        auto dateIt = arguments->find(flutter::EncodableValue("selectedDate"));
        if (dateIt != arguments->end()) {
            selected_date_ms_ = std::get<double>(dateIt->second);
        }
    }

    // 如果没有指定日期，使用当前时间
    if (selected_date_ms_ == 0) {
        selected_date_ms_ = static_cast<double>(std::time(nullptr)) * 1000.0;
    }
}

QuickAddWindow::~QuickAddWindow() {
    Destroy();

    if (bg_brush_) {
        DeleteObject(bg_brush_);
        bg_brush_ = nullptr;
    }
    if (edit_font_) {
        DeleteObject(edit_font_);
        edit_font_ = nullptr;
    }
    if (logo_bitmap_) {
        DeleteObject(logo_bitmap_);
        logo_bitmap_ = nullptr;
    }
}

bool QuickAddWindow::RegisterWindowClass() {
    if (class_registered_) return true;

    WNDCLASSEXW wcex = {};
    wcex.cbSize = sizeof(WNDCLASSEX);
    wcex.style = CS_HREDRAW | CS_VREDRAW | CS_DROPSHADOW;
    wcex.lpfnWndProc = WindowProc;
    wcex.cbClsExtra = 0;
    wcex.cbWndExtra = sizeof(QuickAddWindow*);
    wcex.hInstance = GetModuleHandle(nullptr);
    wcex.hIcon = nullptr;
    wcex.hCursor = LoadCursor(nullptr, IDC_ARROW);
    wcex.hbrBackground = nullptr;  // 自定义绘制
    wcex.lpszMenuName = nullptr;
    wcex.lpszClassName = kWindowClassName;
    wcex.hIconSm = nullptr;

    if (!RegisterClassExW(&wcex)) {
        std::cerr << "[QuickAddWindow] Failed to register window class" << std::endl;
        return false;
    }

    class_registered_ = true;
    return true;
}

bool QuickAddWindow::CreateWindow() {
    if (!RegisterWindowClass()) {
        return false;
    }

    // 获取主屏幕尺寸
    int screenWidth = GetSystemMetrics(SM_CXSCREEN);
    int screenHeight = GetSystemMetrics(SM_CYSCREEN);

    // 计算窗口位置（居中偏上，类似 Spotlight）
    int x = (screenWidth - kWindowWidth) / 2;
    int y = screenHeight / 4;  // 距离顶部 1/4 处

    // 创建无边框窗口
    window_handle_ = CreateWindowExW(
        WS_EX_TOPMOST | WS_EX_TOOLWINDOW,  // 置顶 + 不显示在任务栏
        kWindowClassName,
        L"琥珀闪念",
        WS_POPUP,  // 无边框
        x, y, kWindowWidth, kWindowHeight,
        nullptr, nullptr,
        GetModuleHandle(nullptr),
        this  // 传递 this 指针
    );

    if (!window_handle_) {
        std::cerr << "[QuickAddWindow] Failed to create window" << std::endl;
        return false;
    }

    // 设置圆角（Windows 11+）
    DWMNCRENDERINGPOLICY policy = DWMNCRP_ENABLED;
    DwmSetWindowAttribute(window_handle_, DWMWA_NCRENDERING_POLICY, &policy, sizeof(policy));

    // Windows 11 圆角
    DWM_WINDOW_CORNER_PREFERENCE corner = DWMWCP_ROUND;
    DwmSetWindowAttribute(window_handle_, DWMWA_WINDOW_CORNER_PREFERENCE, &corner, sizeof(corner));

    // 创建控件
    CreateControls();

    return true;
}

void QuickAddWindow::CreateControls() {
    // 创建白色背景画刷
    bg_brush_ = CreateSolidBrush(RGB(255, 255, 255));

    // 创建字体
    edit_font_ = CreateFontW(
        18, 0, 0, 0, FW_MEDIUM, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE,
        L"Microsoft YaHei UI"
    );

    // 输入框（带占位符）
    edit_handle_ = CreateWindowExW(
        0,
        L"EDIT",
        L"",
        WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL,
        56, 16, 420, 28,  // 留出 Logo 空间
        window_handle_,
        reinterpret_cast<HMENU>(ID_EDIT),
        GetModuleHandle(nullptr),
        nullptr
    );

    // 设置输入框字体
    SendMessage(edit_handle_, WM_SETFONT, reinterpret_cast<WPARAM>(edit_font_), TRUE);

    // 子类化输入框以拦截 Enter/ESC 键盘事件
    SetWindowLongPtr(edit_handle_, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(this));
    original_edit_proc_ = reinterpret_cast<WNDPROC>(
        SetWindowLongPtr(edit_handle_, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(EditSubclassProc))
    );

    // 设置占位符文本（Windows Vista+）
    UpdatePlaceholder();

    // 日期按钮
    date_button_ = CreateWindowExW(
        0,
        L"BUTTON",
        L"📅",
        WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON | BS_FLAT,
        486, 14, 32, 32,
        window_handle_,
        reinterpret_cast<HMENU>(ID_DATE_BTN),
        GetModuleHandle(nullptr),
        nullptr
    );

    // 提交按钮
    submit_button_ = CreateWindowExW(
        0,
        L"BUTTON",
        L"↵",
        WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
        526, 14, 60, 32,
        window_handle_,
        reinterpret_cast<HMENU>(ID_SUBMIT_BTN),
        GetModuleHandle(nullptr),
        nullptr
    );
}

void QuickAddWindow::Show(const flutter::EncodableMap* arguments) {
    // 更新选中日期
    if (arguments) {
        auto dateIt = arguments->find(flutter::EncodableValue("selectedDate"));
        if (dateIt != arguments->end()) {
            selected_date_ms_ = std::get<double>(dateIt->second);
            UpdatePlaceholder();
        }
    }

    // 如果窗口不存在，创建它
    if (!window_handle_) {
        if (!CreateWindow()) {
            return;
        }
    }

    // 显示窗口
    ShowWindow(window_handle_, SW_SHOW);
    UpdateWindow(window_handle_);

    // 激活并聚焦
    SetForegroundWindow(window_handle_);
    FocusInput();

    std::cout << "[QuickAddWindow] Window shown" << std::endl;
}

void QuickAddWindow::Hide() {
    if (window_handle_) {
        ShowWindow(window_handle_, SW_HIDE);
        ClearInput();
    }
    std::cout << "[QuickAddWindow] Window hidden" << std::endl;
}

void QuickAddWindow::Destroy() {
    if (window_handle_) {
        DestroyWindow(window_handle_);
        window_handle_ = nullptr;
        edit_handle_ = nullptr;
        date_button_ = nullptr;
        submit_button_ = nullptr;
    }
    std::cout << "[QuickAddWindow] Window destroyed" << std::endl;
}

void QuickAddWindow::HandleFlutterMessage(
    const std::string& method,
    const flutter::EncodableValue* arguments,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

    if (method == "updateDate") {
        if (arguments) {
            const auto* args = std::get_if<flutter::EncodableMap>(arguments);
            if (args) {
                auto dateIt = args->find(flutter::EncodableValue("date"));
                if (dateIt != args->end()) {
                    selected_date_ms_ = std::get<double>(dateIt->second);
                    UpdatePlaceholder();

                    flutter::EncodableMap response;
                    response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
                    result->Success(flutter::EncodableValue(response));
                    return;
                }
            }
        }
        result->Error("INVALID_ARGS", "Missing date");
    } else if (method == "focus") {
        FocusInput();

        flutter::EncodableMap response;
        response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
        result->Success(flutter::EncodableValue(response));
    } else {
        result->NotImplemented();
    }
}

LRESULT CALLBACK QuickAddWindow::WindowProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
    QuickAddWindow* window = nullptr;

    if (message == WM_NCCREATE) {
        CREATESTRUCT* cs = reinterpret_cast<CREATESTRUCT*>(lparam);
        window = reinterpret_cast<QuickAddWindow*>(cs->lpCreateParams);
        SetWindowLongPtr(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(window));
    } else {
        window = reinterpret_cast<QuickAddWindow*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));
    }

    if (window) {
        return window->HandleMessage(hwnd, message, wparam, lparam);
    }

    return DefWindowProc(hwnd, message, wparam, lparam);
}

LRESULT QuickAddWindow::HandleMessage(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
    switch (message) {
        case WM_PAINT:
            OnPaint();
            return 0;

        case WM_COMMAND:
            OnCommand(LOWORD(wparam), HIWORD(wparam));
            return 0;

        case WM_KEYDOWN:
            OnKeyDown(wparam);
            return 0;

        case WM_CTLCOLOREDIT: {
            // 设置输入框背景色
            HDC hdc = reinterpret_cast<HDC>(wparam);
            SetBkColor(hdc, RGB(255, 255, 255));
            SetTextColor(hdc, RGB(0, 0, 0));
            return reinterpret_cast<LRESULT>(bg_brush_);
        }

        case WM_ACTIVATE:
            if (LOWORD(wparam) == WA_INACTIVE) {
                // 窗口失去焦点时隐藏（类似 Spotlight 行为）
                // 注意：可以根据需要调整此行为
                // Hide();
                // NativeWindowManager::GetInstance().WindowDidClose(GetWindowType(), window_id_);
            }
            return 0;

        case WM_DESTROY:
            window_handle_ = nullptr;
            return 0;

        default:
            return DefWindowProc(hwnd, message, wparam, lparam);
    }
}

void QuickAddWindow::OnPaint() {
    PAINTSTRUCT ps;
    HDC hdc = BeginPaint(window_handle_, &ps);

    // 获取客户区大小
    RECT rect;
    GetClientRect(window_handle_, &rect);

    // 创建内存 DC
    HDC memDC = CreateCompatibleDC(hdc);
    HBITMAP memBitmap = CreateCompatibleBitmap(hdc, rect.right, rect.bottom);
    HBITMAP oldBitmap = static_cast<HBITMAP>(SelectObject(memDC, memBitmap));

    // 填充白色背景
    FillRect(memDC, &rect, bg_brush_);

    // 绘制 Logo 区域（琥珀色圆形）
    HBRUSH logoBrush = CreateSolidBrush(RGB(245, 166, 35));  // 琥珀金 #F5A623
    HBRUSH oldBrush = static_cast<HBRUSH>(SelectObject(memDC, logoBrush));
    HPEN nullPen = CreatePen(PS_NULL, 0, 0);
    HPEN oldPen = static_cast<HPEN>(SelectObject(memDC, nullPen));

    Ellipse(memDC, 12, 14, 44, 46);  // 32x32 圆形

    // 在圆形中心绘制琥珀图标（简化为文字）
    SetBkMode(memDC, TRANSPARENT);
    SetTextColor(memDC, RGB(255, 255, 255));

    HFONT iconFont = CreateFontW(
        16, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE,
        L"Segoe UI Emoji"
    );
    HFONT oldFont = static_cast<HFONT>(SelectObject(memDC, iconFont));

    RECT logoRect = {12, 14, 44, 46};
    DrawTextW(memDC, L"🪲", -1, &logoRect, DT_CENTER | DT_VCENTER | DT_SINGLELINE);

    // 清理
    SelectObject(memDC, oldFont);
    DeleteObject(iconFont);
    SelectObject(memDC, oldBrush);
    SelectObject(memDC, oldPen);
    DeleteObject(logoBrush);
    DeleteObject(nullPen);

    // 复制到窗口
    BitBlt(hdc, 0, 0, rect.right, rect.bottom, memDC, 0, 0, SRCCOPY);

    // 清理内存 DC
    SelectObject(memDC, oldBitmap);
    DeleteObject(memBitmap);
    DeleteDC(memDC);

    EndPaint(window_handle_, &ps);
}

void QuickAddWindow::OnCommand(WORD id, WORD code) {
    switch (id) {
        case ID_EDIT:
            if (code == EN_CHANGE) {
                // 输入变化时可以做一些处理
            }
            break;

        case ID_DATE_BTN:
            RequestDatePicker();
            break;

        case ID_SUBMIT_BTN:
            SubmitTask();
            break;
    }
}

void QuickAddWindow::OnKeyDown(WPARAM key) {
    // 注意：主窗口的 WM_KEYDOWN 通常不会被调用，因为输入框会捕获键盘事件
    // 键盘事件（Enter/ESC）在 EditSubclassProc 中处理
    if (key == VK_RETURN) {
        SubmitTask();
    } else if (key == VK_ESCAPE) {
        CancelInput();
    }
}

LRESULT CALLBACK QuickAddWindow::EditSubclassProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam) {
    // 获取 QuickAddWindow 实例指针
    auto* window = reinterpret_cast<QuickAddWindow*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));
    if (!window || !window->original_edit_proc_) {
        return DefWindowProc(hwnd, msg, wparam, lparam);
    }

    if (msg == WM_KEYDOWN) {
        if (wparam == VK_RETURN) {
            // Enter 键：提交任务
            window->SubmitTask();
            return 0;
        } else if (wparam == VK_ESCAPE) {
            // ESC 键：取消输入
            window->CancelInput();
            return 0;
        }
    }

    // 调用原始窗口过程处理其他消息
    return CallWindowProc(window->original_edit_proc_, hwnd, msg, wparam, lparam);
}

void QuickAddWindow::SubmitTask() {
    std::wstring title = GetInputText();

    // 去除首尾空格
    size_t start = title.find_first_not_of(L" \t\n\r");
    size_t end = title.find_last_not_of(L" \t\n\r");
    if (start == std::wstring::npos || end == std::wstring::npos) {
        return;  // 空白输入，不提交
    }
    title = title.substr(start, end - start + 1);

    if (title.empty()) {
        return;
    }

    // 通知 Flutter 创建任务
    flutter::EncodableMap args;
    args[flutter::EncodableValue("title")] = flutter::EncodableValue(
        NativeWindowManager::WStringToUtf8(title)
    );
    args[flutter::EncodableValue("dueDate")] = flutter::EncodableValue(selected_date_ms_);
    args[flutter::EncodableValue("windowType")] = flutter::EncodableValue(GetWindowType());
    if (!window_id_.empty()) {
        args[flutter::EncodableValue("windowId")] = flutter::EncodableValue(
            NativeWindowManager::WStringToUtf8(window_id_)
        );
    }

    NativeWindowManager::GetInstance().NotifyFlutter("onQuickAddTaskCreated", args);

    // 隐藏窗口
    Hide();

    std::cout << "[QuickAddWindow] Task submitted: " << NativeWindowManager::WStringToUtf8(title) << std::endl;
}

void QuickAddWindow::CancelInput() {
    // 通知 Flutter 取消
    flutter::EncodableMap args;
    args[flutter::EncodableValue("windowType")] = flutter::EncodableValue(GetWindowType());
    if (!window_id_.empty()) {
        args[flutter::EncodableValue("windowId")] = flutter::EncodableValue(
            NativeWindowManager::WStringToUtf8(window_id_)
        );
    }

    NativeWindowManager::GetInstance().NotifyFlutter("onQuickAddCancelled", args);

    // 隐藏窗口
    Hide();

    std::cout << "[QuickAddWindow] Input cancelled" << std::endl;
}

void QuickAddWindow::RequestDatePicker() {
    // 通知 Flutter 打开日期选择器
    flutter::EncodableMap args;
    args[flutter::EncodableValue("currentDate")] = flutter::EncodableValue(selected_date_ms_);
    args[flutter::EncodableValue("windowType")] = flutter::EncodableValue(GetWindowType());
    if (!window_id_.empty()) {
        args[flutter::EncodableValue("windowId")] = flutter::EncodableValue(
            NativeWindowManager::WStringToUtf8(window_id_)
        );
    }

    NativeWindowManager::GetInstance().NotifyFlutter("onDatePickerRequested", args);

    std::cout << "[QuickAddWindow] Date picker requested" << std::endl;
}

std::wstring QuickAddWindow::FormatDate(double timestamp) {
    // 将毫秒时间戳转换为 time_t
    time_t time = static_cast<time_t>(timestamp / 1000);

    // 使用线程安全的 localtime_s（Windows 特有）
    struct tm tm_info;
    if (localtime_s(&tm_info, &time) != 0) {
        return L"未知日期";
    }

    std::wstringstream ss;
    ss << (tm_info.tm_mon + 1) << L"月" << tm_info.tm_mday << L"日";
    return ss.str();
}

std::wstring QuickAddWindow::GetInputText() {
    if (!edit_handle_) return L"";

    int length = GetWindowTextLengthW(edit_handle_);
    if (length == 0) return L"";

    std::wstring text(length + 1, 0);
    GetWindowTextW(edit_handle_, &text[0], length + 1);
    text.resize(length);
    return text;
}

void QuickAddWindow::ClearInput() {
    if (edit_handle_) {
        SetWindowTextW(edit_handle_, L"");
    }
}

void QuickAddWindow::FocusInput() {
    if (edit_handle_) {
        SetFocus(edit_handle_);
    }
}

void QuickAddWindow::UpdatePlaceholder() {
    if (edit_handle_) {
        std::wstring placeholder = L"添加任务到 " + FormatDate(selected_date_ms_) + L"...";
        SendMessageW(edit_handle_, EM_SETCUEBANNER, TRUE, reinterpret_cast<LPARAM>(placeholder.c_str()));
    }
}
