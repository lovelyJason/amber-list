#include "sticky_note_window.h"
#include <windowsx.h>
#include <uxtheme.h>
#include <algorithm>

#pragma comment(lib, "uxtheme.lib")
#pragma comment(lib, "comctl32.lib")

// 静态成员初始化
const wchar_t* StickyNoteWindow::kWindowClassName = L"AMBER_STICKY_NOTE_WINDOW";
bool StickyNoteWindow::class_registered_ = false;

// 预定义主题色
static const COLORREF kThemeColors[] = {
    RGB(255, 247, 209),  // Yellow: 0xFFFFF7D1
    RGB(225, 245, 254),  // Blue: 0xFFE1F5FE
    RGB(255, 235, 238),  // Pink: 0xFFFFEBEE
    RGB(232, 245, 233),  // Green: 0xFFE8F5E9
};

// 窗口尺寸常量
static const int kWindowWidth = 320;
static const int kWindowHeight = 400;
static const int kHeaderHeight = 32;
static const int kPadding = 16;
static const int kButtonSize = 24;

StickyNoteWindow::StickyNoteWindow(const std::wstring& noteId,
                                   const std::wstring& title,
                                   COLORREF themeColor)
    : note_id_(noteId),
      note_title_(title),
      theme_color_(themeColor) {
    bg_brush_ = CreateSolidBrush(theme_color_);

    // 头部稍微深一点
    int r = GetRValue(theme_color_);
    int g = GetGValue(theme_color_);
    int b = GetBValue(theme_color_);
    header_brush_ = CreateSolidBrush(RGB(
        std::max(0, r - 10),
        std::max(0, g - 10),
        std::max(0, b - 10)
    ));
}

StickyNoteWindow::~StickyNoteWindow() {
    if (bg_brush_) DeleteObject(bg_brush_);
    if (header_brush_) DeleteObject(header_brush_);
    if (window_handle_) DestroyWindow(window_handle_);
}

bool StickyNoteWindow::RegisterWindowClass() {
    if (class_registered_) return true;

    WNDCLASSEXW wcex = {};
    wcex.cbSize = sizeof(WNDCLASSEXW);
    wcex.style = CS_HREDRAW | CS_VREDRAW;
    wcex.lpfnWndProc = WindowProc;
    wcex.hInstance = GetModuleHandle(nullptr);
    wcex.hCursor = LoadCursor(nullptr, IDC_ARROW);
    wcex.hbrBackground = nullptr;  // 自定义绘制
    wcex.lpszClassName = kWindowClassName;

    if (!RegisterClassExW(&wcex)) {
        return false;
    }

    class_registered_ = true;
    return true;
}

bool StickyNoteWindow::Create() {
    if (!RegisterWindowClass()) {
        return false;
    }

    // 计算居中位置
    int screenWidth = GetSystemMetrics(SM_CXSCREEN);
    int screenHeight = GetSystemMetrics(SM_CYSCREEN);
    int x = (screenWidth - kWindowWidth) / 2;
    int y = (screenHeight - kWindowHeight) / 2;

    // 创建窗口
    window_handle_ = CreateWindowExW(
        WS_EX_TOOLWINDOW | (is_pinned_ ? WS_EX_TOPMOST : 0),
        kWindowClassName,
        L"琥珀便签",
        WS_OVERLAPPEDWINDOW & ~WS_MAXIMIZEBOX,  // 不允许最大化
        x, y, kWindowWidth, kWindowHeight,
        nullptr, nullptr,
        GetModuleHandle(nullptr),
        this  // 传递 this 指针
    );

    if (!window_handle_) {
        return false;
    }

    // 设置窗口大小限制
    // 在 WM_GETMINMAXINFO 中处理

    // 创建控件
    CreateControls();

    return true;
}

void StickyNoteWindow::Show() {
    if (window_handle_) {
        ShowWindow(window_handle_, SW_SHOWNORMAL);
        UpdateWindow(window_handle_);
        SetForegroundWindow(window_handle_);
    }
}

void StickyNoteWindow::Close() {
    if (window_handle_) {
        DestroyWindow(window_handle_);
        window_handle_ = nullptr;
    }
}

void StickyNoteWindow::Focus() {
    if (window_handle_) {
        if (IsIconic(window_handle_)) {
            ShowWindow(window_handle_, SW_RESTORE);
        }
        SetForegroundWindow(window_handle_);
        SetFocus(window_handle_);
    }
}

void StickyNoteWindow::UpdateTasks(const std::vector<TaskItem>& active,
                                    const std::vector<TaskItem>& completed) {
    active_tasks_ = active;
    completed_tasks_ = completed;
    RebuildTaskList();
}

void StickyNoteWindow::SetPinned(bool pinned) {
    is_pinned_ = pinned;
    if (window_handle_) {
        SetWindowPos(
            window_handle_,
            is_pinned_ ? HWND_TOPMOST : HWND_NOTOPMOST,
            0, 0, 0, 0,
            SWP_NOMOVE | SWP_NOSIZE
        );
        // 更新按钮文字
        if (pin_button_) {
            SetWindowTextW(pin_button_, is_pinned_ ? L"📌" : L"📍");
        }
    }
}

void StickyNoteWindow::SetThemeColor(COLORREF color) {
    theme_color_ = color;

    // 重建画刷
    if (bg_brush_) DeleteObject(bg_brush_);
    if (header_brush_) DeleteObject(header_brush_);

    bg_brush_ = CreateSolidBrush(theme_color_);

    int r = GetRValue(theme_color_);
    int g = GetGValue(theme_color_);
    int b = GetBValue(theme_color_);
    header_brush_ = CreateSolidBrush(RGB(
        std::max(0, r - 10),
        std::max(0, g - 10),
        std::max(0, b - 10)
    ));

    // 强制重绘
    if (window_handle_) {
        InvalidateRect(window_handle_, nullptr, TRUE);
    }
}

LRESULT CALLBACK StickyNoteWindow::WindowProc(HWND hwnd, UINT message,
                                               WPARAM wparam, LPARAM lparam) {
    StickyNoteWindow* self = nullptr;

    if (message == WM_NCCREATE) {
        auto createStruct = reinterpret_cast<CREATESTRUCT*>(lparam);
        self = static_cast<StickyNoteWindow*>(createStruct->lpCreateParams);
        SetWindowLongPtr(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
    } else {
        self = reinterpret_cast<StickyNoteWindow*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));
    }

    if (self) {
        return self->HandleMessage(message, wparam, lparam);
    }

    return DefWindowProcW(hwnd, message, wparam, lparam);
}

LRESULT StickyNoteWindow::HandleMessage(UINT message, WPARAM wparam, LPARAM lparam) {
    switch (message) {
        case WM_CREATE:
            return 0;

        case WM_PAINT:
            OnPaint();
            return 0;

        case WM_ERASEBKGND:
            return 1;  // 自己处理背景绘制

        case WM_CTLCOLORSTATIC:
        case WM_CTLCOLORBTN: {
            // 设置控件背景透明
            HDC hdc = reinterpret_cast<HDC>(wparam);
            SetBkMode(hdc, TRANSPARENT);
            return reinterpret_cast<LRESULT>(bg_brush_);
        }

        case WM_COMMAND: {
            int controlId = LOWORD(wparam);
            int notifyCode = HIWORD(wparam);

            // Checkbox 点击
            if (notifyCode == BN_CLICKED) {
                if (controlId >= 100 && controlId < 1000) {
                    OnCheckboxClicked(controlId);
                } else {
                    OnButtonClicked(controlId);
                }
            }
            return 0;
        }

        case WM_GETMINMAXINFO: {
            auto minmax = reinterpret_cast<MINMAXINFO*>(lparam);
            minmax->ptMinTrackSize.x = 200;
            minmax->ptMinTrackSize.y = 200;
            minmax->ptMaxTrackSize.x = 600;
            minmax->ptMaxTrackSize.y = 800;
            return 0;
        }

        case WM_CLOSE:
            // 通知 Flutter 窗口关闭
            if (onWindowClosed) {
                onWindowClosed(note_id_);
            }
            DestroyWindow(window_handle_);
            window_handle_ = nullptr;
            return 0;

        case WM_DESTROY:
            return 0;

        case WM_SIZE:
            // 窗口大小变化时重新布局
            RebuildTaskList();
            return 0;

        case WM_NCHITTEST: {
            // 允许拖动窗口（头部区域）
            POINT pt = { GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam) };
            ScreenToClient(window_handle_, &pt);
            if (pt.y < kHeaderHeight && pt.x < (kWindowWidth - kButtonSize * 3 - kPadding)) {
                return HTCAPTION;
            }
            break;
        }
    }

    return DefWindowProcW(window_handle_, message, wparam, lparam);
}

void StickyNoteWindow::CreateControls() {
    if (!window_handle_) return;

    HFONT hFont = CreateFontW(
        14, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Microsoft YaHei"
    );

    HFONT hTitleFont = CreateFontW(
        18, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Microsoft YaHei"
    );

    // 头部按钮
    int buttonX = kWindowWidth - kPadding - kButtonSize * 3 - 8;
    int buttonY = (kHeaderHeight - kButtonSize) / 2;

    // 颜色按钮
    color_button_ = CreateWindowW(
        L"BUTTON", L"🎨",
        WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON | BS_FLAT,
        buttonX, buttonY, kButtonSize, kButtonSize,
        window_handle_, reinterpret_cast<HMENU>(ID_BTN_COLOR),
        GetModuleHandle(nullptr), nullptr
    );

    // 置顶按钮
    pin_button_ = CreateWindowW(
        L"BUTTON", is_pinned_ ? L"📌" : L"📍",
        WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON | BS_FLAT,
        buttonX + kButtonSize + 4, buttonY, kButtonSize, kButtonSize,
        window_handle_, reinterpret_cast<HMENU>(ID_BTN_PIN),
        GetModuleHandle(nullptr), nullptr
    );

    // 关闭按钮
    close_button_ = CreateWindowW(
        L"BUTTON", L"✕",
        WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON | BS_FLAT,
        buttonX + (kButtonSize + 4) * 2, buttonY, kButtonSize, kButtonSize,
        window_handle_, reinterpret_cast<HMENU>(ID_BTN_CLOSE),
        GetModuleHandle(nullptr), nullptr
    );

    // 标题标签
    title_label_ = CreateWindowW(
        L"STATIC", note_title_.c_str(),
        WS_CHILD | WS_VISIBLE | SS_LEFT,
        kPadding, kHeaderHeight + 12, kWindowWidth - kPadding * 2, 24,
        window_handle_, nullptr,
        GetModuleHandle(nullptr), nullptr
    );
    SendMessage(title_label_, WM_SETFONT, reinterpret_cast<WPARAM>(hTitleFont), TRUE);

    // 初始化任务列表
    RebuildTaskList();
}

void StickyNoteWindow::RebuildTaskList() {
    if (!window_handle_) return;

    // 清除旧的 checkbox
    for (auto& pair : checkbox_task_map_) {
        HWND checkbox = GetDlgItem(window_handle_, pair.first);
        if (checkbox) DestroyWindow(checkbox);
    }
    checkbox_task_map_.clear();
    next_control_id_ = 100;

    HFONT hFont = CreateFontW(
        14, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Microsoft YaHei"
    );

    int y = kHeaderHeight + 48;  // 标题下方

    // 活跃任务
    for (const auto& task : active_tasks_) {
        int id = next_control_id_++;
        checkbox_task_map_[id] = task.id;

        HWND checkbox = CreateWindowW(
            L"BUTTON", task.title.c_str(),
            WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX,
            kPadding, y, kWindowWidth - kPadding * 2, 24,
            window_handle_, reinterpret_cast<HMENU>(static_cast<INT_PTR>(id)),
            GetModuleHandle(nullptr), nullptr
        );
        SendMessage(checkbox, WM_SETFONT, reinterpret_cast<WPARAM>(hFont), TRUE);
        SendMessage(checkbox, BM_SETCHECK, task.isCompleted ? BST_CHECKED : BST_UNCHECKED, 0);

        y += 28;
    }

    // 分隔线（如果两者都有）
    if (!active_tasks_.empty() && !completed_tasks_.empty()) {
        y += 8;
        // 分隔线用静态控件绘制
        HWND separator = CreateWindowW(
            L"STATIC", L"",
            WS_CHILD | WS_VISIBLE | SS_ETCHEDHORZ,
            kPadding, y, kWindowWidth - kPadding * 2, 2,
            window_handle_, nullptr,
            GetModuleHandle(nullptr), nullptr
        );
        y += 10;
    }

    // 已完成任务
    for (const auto& task : completed_tasks_) {
        int id = next_control_id_++;
        checkbox_task_map_[id] = task.id;

        HWND checkbox = CreateWindowW(
            L"BUTTON", task.title.c_str(),
            WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX,
            kPadding, y, kWindowWidth - kPadding * 2, 24,
            window_handle_, reinterpret_cast<HMENU>(static_cast<INT_PTR>(id)),
            GetModuleHandle(nullptr), nullptr
        );
        SendMessage(checkbox, WM_SETFONT, reinterpret_cast<WPARAM>(hFont), TRUE);
        SendMessage(checkbox, BM_SETCHECK, BST_CHECKED, 0);
        // 可以考虑设置灰色文字表示已完成

        y += 28;
    }

    // 无任务提示
    if (active_tasks_.empty() && completed_tasks_.empty()) {
        CreateWindowW(
            L"STATIC", L"暂无任务",
            WS_CHILD | WS_VISIBLE | SS_LEFT,
            kPadding, y, 200, 20,
            window_handle_, nullptr,
            GetModuleHandle(nullptr), nullptr
        );
    }

    InvalidateRect(window_handle_, nullptr, TRUE);
}

void StickyNoteWindow::OnPaint() {
    PAINTSTRUCT ps;
    HDC hdc = BeginPaint(window_handle_, &ps);

    RECT rect;
    GetClientRect(window_handle_, &rect);

    // 头部背景
    RECT headerRect = { 0, 0, rect.right, kHeaderHeight };
    FillRect(hdc, &headerRect, header_brush_);

    // 绘制头部文字 "琥珀便签"
    SetBkMode(hdc, TRANSPARENT);
    SetTextColor(hdc, RGB(100, 100, 100));

    HFONT hFont = CreateFontW(
        12, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Microsoft YaHei"
    );
    HFONT oldFont = static_cast<HFONT>(SelectObject(hdc, hFont));

    TextOutW(hdc, 12, 8, L"📝 琥珀便签", 6);

    SelectObject(hdc, oldFont);
    DeleteObject(hFont);

    // 内容区背景
    RECT contentRect = { 0, kHeaderHeight, rect.right, rect.bottom };
    FillRect(hdc, &contentRect, bg_brush_);

    EndPaint(window_handle_, &ps);
}

void StickyNoteWindow::OnCheckboxClicked(int checkboxId) {
    auto it = checkbox_task_map_.find(checkboxId);
    if (it == checkbox_task_map_.end()) return;

    const std::wstring& taskId = it->second;

    // 获取新状态
    HWND checkbox = GetDlgItem(window_handle_, checkboxId);
    bool isChecked = (SendMessage(checkbox, BM_GETCHECK, 0, 0) == BST_CHECKED);

    // 更新本地数据
    // 在 active 和 completed 之间移动
    if (isChecked) {
        // 移到 completed
        for (auto taskIt = active_tasks_.begin(); taskIt != active_tasks_.end(); ++taskIt) {
            if (taskIt->id == taskId) {
                TaskItem task = *taskIt;
                task.isCompleted = true;
                active_tasks_.erase(taskIt);
                completed_tasks_.push_back(task);
                break;
            }
        }
    } else {
        // 移到 active
        for (auto taskIt = completed_tasks_.begin(); taskIt != completed_tasks_.end(); ++taskIt) {
            if (taskIt->id == taskId) {
                TaskItem task = *taskIt;
                task.isCompleted = false;
                completed_tasks_.erase(taskIt);
                active_tasks_.push_back(task);
                break;
            }
        }
    }

    // 重建列表（重新排序）
    RebuildTaskList();

    // 通知 Flutter
    if (onTaskToggled) {
        onTaskToggled(taskId, isChecked);
    }
}

void StickyNoteWindow::OnButtonClicked(int buttonId) {
    switch (buttonId) {
        case ID_BTN_PIN:
            TogglePin();
            break;
        case ID_BTN_COLOR:
            if (color_picker_visible_) {
                HideColorPicker();
            } else {
                ShowColorPicker();
            }
            break;
        case ID_BTN_CLOSE:
            Close();
            break;
        case ID_BTN_COLOR_1:
            SetThemeColor(kThemeColors[0]);
            HideColorPicker();
            break;
        case ID_BTN_COLOR_2:
            SetThemeColor(kThemeColors[1]);
            HideColorPicker();
            break;
        case ID_BTN_COLOR_3:
            SetThemeColor(kThemeColors[2]);
            HideColorPicker();
            break;
        case ID_BTN_COLOR_4:
            SetThemeColor(kThemeColors[3]);
            HideColorPicker();
            break;
    }
}

void StickyNoteWindow::TogglePin() {
    SetPinned(!is_pinned_);
}

void StickyNoteWindow::ShowColorPicker() {
    if (color_picker_visible_) return;
    color_picker_visible_ = true;

    // 隐藏原有按钮
    ShowWindow(pin_button_, SW_HIDE);
    ShowWindow(color_button_, SW_HIDE);
    ShowWindow(close_button_, SW_HIDE);

    int buttonY = (kHeaderHeight - 16) / 2;
    int x = kWindowWidth - kPadding - (20 * 4 + 12);

    // 创建颜色选择按钮
    for (int i = 0; i < 4; i++) {
        HWND colorBtn = CreateWindowW(
            L"BUTTON", L"",
            WS_CHILD | WS_VISIBLE | BS_OWNERDRAW,
            x + i * 20, buttonY, 16, 16,
            window_handle_, reinterpret_cast<HMENU>(static_cast<INT_PTR>(ID_BTN_COLOR_1 + i)),
            GetModuleHandle(nullptr), nullptr
        );
    }
}

void StickyNoteWindow::HideColorPicker() {
    if (!color_picker_visible_) return;
    color_picker_visible_ = false;

    // 销毁颜色按钮
    for (int i = 0; i < 4; i++) {
        HWND btn = GetDlgItem(window_handle_, ID_BTN_COLOR_1 + i);
        if (btn) DestroyWindow(btn);
    }

    // 显示原有按钮
    ShowWindow(pin_button_, SW_SHOW);
    ShowWindow(color_button_, SW_SHOW);
    ShowWindow(close_button_, SW_SHOW);
}
