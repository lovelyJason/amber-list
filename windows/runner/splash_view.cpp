#include "splash_view.h"

#include <algorithm>
#include <cmath>
#include <string>
#include <iostream>

// Static member initialization
SplashTransitionType SplashView::transition_type = SplashTransitionType::kFadeOut;
double SplashView::transition_duration = 0.3;
bool SplashView::show_progress_bar = true;

const wchar_t* SplashView::kWindowClassName = L"AmberSplashView";
bool SplashView::class_registered_ = false;
ULONG_PTR SplashView::gdiplus_token_ = 0;
bool SplashView::gdiplus_initialized_ = false;

// Animation constants
static const UINT_PTR kBreathingTimerId = 1001;
static const UINT_PTR kProgressTimerId = 1002;
static const UINT_PTR kFadeTimerId = 1003;
static const UINT_PTR kGifTimerId = 1004;
static const int kAnimationInterval = 16;  // ~60fps
static const int kProgressInterval = 50;   // Progress update interval
static const int kFadeInterval = 16;       // Fade animation interval

SplashView::SplashView(HWND parent_window)
    : parent_window_(parent_window) {
    // Initialize GDI+ if not already done
    if (!gdiplus_initialized_) {
        Gdiplus::GdiplusStartupInput gdiplusStartupInput;
        Gdiplus::GdiplusStartup(&gdiplus_token_, &gdiplusStartupInput, nullptr);
        gdiplus_initialized_ = true;
    }
}

SplashView::~SplashView() {
    // Stop all timers
    if (splash_window_) {
        if (animation_timer_id_) {
            KillTimer(splash_window_, animation_timer_id_);
        }
        if (progress_timer_id_) {
            KillTimer(splash_window_, progress_timer_id_);
        }
        if (fade_timer_id_) {
            KillTimer(splash_window_, fade_timer_id_);
        }
        if (gif_timer_id_) {
            KillTimer(splash_window_, gif_timer_id_);
        }
        DestroyWindow(splash_window_);
        splash_window_ = nullptr;
    }

    // Free GIF frame delays
    if (gif_frame_delays_) {
        delete[] gif_frame_delays_;
        gif_frame_delays_ = nullptr;
    }
}

bool SplashView::RegisterWindowClass() {
    if (class_registered_) {
        return true;
    }

    WNDCLASSEXW wcex = {};
    wcex.cbSize = sizeof(WNDCLASSEXW);
    wcex.style = CS_HREDRAW | CS_VREDRAW;
    wcex.lpfnWndProc = WindowProc;
    wcex.cbClsExtra = 0;
    wcex.cbWndExtra = sizeof(SplashView*);
    wcex.hInstance = GetModuleHandle(nullptr);
    wcex.hCursor = LoadCursor(nullptr, IDC_ARROW);
    wcex.hbrBackground = nullptr;
    wcex.lpszClassName = kWindowClassName;

    if (RegisterClassExW(&wcex) == 0) {
        return false;
    }

    class_registered_ = true;
    return true;
}

bool SplashView::Create() {
    if (!RegisterWindowClass()) {
        return false;
    }

    // Get DPI scale
    HDC hdc = GetDC(parent_window_);
    dpi_scale_ = static_cast<float>(GetDeviceCaps(hdc, LOGPIXELSX)) / 96.0f;
    ReleaseDC(parent_window_, hdc);

    // Get parent window client area
    RECT parent_rect;
    GetClientRect(parent_window_, &parent_rect);
    int width = parent_rect.right - parent_rect.left;
    int height = parent_rect.bottom - parent_rect.top;

    std::cout << "[SplashView] Parent client area: " << width << "x" << height << std::endl;

    // Create splash window as child of parent, covering entire client area
    splash_window_ = CreateWindowExW(
        WS_EX_LAYERED,  // Layered window for alpha blending
        kWindowClassName,
        L"",
        WS_CHILD | WS_VISIBLE,
        0, 0,
        width,
        height,
        parent_window_,
        nullptr,
        GetModuleHandle(nullptr),
        this);

    if (!splash_window_) {
        std::cout << "[SplashView] ERROR: Failed to create window" << std::endl;
        return false;
    }

    // Set initial alpha to fully opaque
    SetLayeredWindowAttributes(splash_window_, 0, 255, LWA_ALPHA);

    // Load logo image
    LoadLogoImage();

    // Bring splash to topmost among siblings (child windows)
    // Use HWND_TOP and add SWP_SHOWWINDOW to ensure visibility
    SetWindowPos(splash_window_, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);

    // Force update the window
    UpdateWindow(splash_window_);

    // Mark as visible (track internally since IsWindowVisible unreliable for child windows)
    is_visible_ = true;
    std::cout << "[SplashView] Created and visible, size: " << width << "x" << height << std::endl;

    return true;
}

bool SplashView::LoadLogoImage() {
    // Get the executable directory
    wchar_t exe_path[MAX_PATH];
    GetModuleFileNameW(nullptr, exe_path, MAX_PATH);

    // Find the last backslash and truncate
    wchar_t* last_slash = wcsrchr(exe_path, L'\\');
    if (last_slash) {
        *last_slash = L'\0';
    }

    // Construct path to logo image
    // Flutter assets are stored in data/flutter_assets/assets/images/
    std::wstring logo_path = exe_path;
    std::wstring loaded_from;

    // 1. Try squirrel_walk.gif first (animated GIF)
    // Note: GDI+ loads GIF but shows only first frame. For full animation,
    // we would need frame-by-frame rendering, but static first frame is acceptable.
    logo_path += L"\\data\\flutter_assets\\assets\\images\\squirrel_walk.gif";
    std::wcout << L"[SplashView] Trying: " << logo_path << std::endl;
    logo_bitmap_ = std::make_unique<Gdiplus::Bitmap>(logo_path.c_str());

    if (logo_bitmap_->GetLastStatus() == Gdiplus::Ok) {
        loaded_from = logo_path;
    } else {
        // 2. Try the removebg version (transparent background)
        logo_path = exe_path;
        logo_path += L"\\data\\flutter_assets\\assets\\images\\amber_squirrel-removebg.png";
        std::wcout << L"[SplashView] Trying: " << logo_path << std::endl;
        logo_bitmap_ = std::make_unique<Gdiplus::Bitmap>(logo_path.c_str());
        if (logo_bitmap_->GetLastStatus() == Gdiplus::Ok) {
            loaded_from = logo_path;
        }
    }

    if (logo_bitmap_->GetLastStatus() != Gdiplus::Ok) {
        // 3. Fall back to regular amber_squirrel
        logo_path = exe_path;
        logo_path += L"\\data\\flutter_assets\\assets\\images\\amber_squirrel.png";
        std::wcout << L"[SplashView] Trying: " << logo_path << std::endl;
        logo_bitmap_ = std::make_unique<Gdiplus::Bitmap>(logo_path.c_str());
        if (logo_bitmap_->GetLastStatus() == Gdiplus::Ok) {
            loaded_from = logo_path;
        }
    }

    if (logo_bitmap_->GetLastStatus() != Gdiplus::Ok) {
        // 4. Try alternate path for debug builds (GIF)
        logo_path = exe_path;
        logo_path += L"\\..\\..\\assets\\images\\squirrel_walk.gif";
        std::wcout << L"[SplashView] Trying: " << logo_path << std::endl;
        logo_bitmap_ = std::make_unique<Gdiplus::Bitmap>(logo_path.c_str());
        if (logo_bitmap_->GetLastStatus() == Gdiplus::Ok) {
            loaded_from = logo_path;
        }
    }

    if (logo_bitmap_->GetLastStatus() != Gdiplus::Ok) {
        // 5. Try alternate path for debug builds (PNG)
        logo_path = exe_path;
        logo_path += L"\\..\\..\\assets\\images\\amber_squirrel-removebg.png";
        std::wcout << L"[SplashView] Trying: " << logo_path << std::endl;
        logo_bitmap_ = std::make_unique<Gdiplus::Bitmap>(logo_path.c_str());
        if (logo_bitmap_->GetLastStatus() == Gdiplus::Ok) {
            loaded_from = logo_path;
        }
    }

    if (logo_bitmap_->GetLastStatus() != Gdiplus::Ok) {
        // 6. Last fallback for debug builds
        logo_path = exe_path;
        logo_path += L"\\..\\..\\assets\\images\\amber_squirrel.png";
        std::wcout << L"[SplashView] Trying: " << logo_path << std::endl;
        logo_bitmap_ = std::make_unique<Gdiplus::Bitmap>(logo_path.c_str());
        if (logo_bitmap_->GetLastStatus() == Gdiplus::Ok) {
            loaded_from = logo_path;
        }
    }

    if (logo_bitmap_ && logo_bitmap_->GetLastStatus() == Gdiplus::Ok) {
        std::wcout << L"[SplashView] Loaded logo from: " << loaded_from << std::endl;

        // Check if it's a GIF and initialize animation
        InitGifAnimation();

        return true;
    }

    std::cout << "[SplashView] Failed to load any logo image!" << std::endl;
    return false;
}

void SplashView::InitGifAnimation() {
    if (!logo_bitmap_) return;

    // Get frame dimension count
    UINT dimension_count = logo_bitmap_->GetFrameDimensionsCount();
    if (dimension_count == 0) {
        is_gif_ = false;
        return;
    }

    // Get the dimension IDs
    GUID* dimension_ids = new GUID[dimension_count];
    logo_bitmap_->GetFrameDimensionsList(dimension_ids, dimension_count);

    // Get frame count for the first dimension (time dimension for GIF)
    gif_frame_count_ = logo_bitmap_->GetFrameCount(&dimension_ids[0]);

    if (gif_frame_count_ > 1) {
        is_gif_ = true;
        gif_current_frame_ = 0;

        // Get frame delays from PropertyTagFrameDelay
        UINT property_size = logo_bitmap_->GetPropertyItemSize(PropertyTagFrameDelay);
        if (property_size > 0) {
            Gdiplus::PropertyItem* property_item = (Gdiplus::PropertyItem*)malloc(property_size);
            if (logo_bitmap_->GetPropertyItem(PropertyTagFrameDelay, property_size, property_item) == Gdiplus::Ok) {
                // Frame delays are in 1/100 second units
                gif_frame_delays_ = new UINT[gif_frame_count_];
                UINT* delays = (UINT*)property_item->value;
                for (UINT i = 0; i < gif_frame_count_; i++) {
                    // Convert from 1/100s to milliseconds
                    gif_frame_delays_[i] = delays[i] * 10;
                    // Minimum delay of 20ms (browsers use this as minimum too)
                    if (gif_frame_delays_[i] < 20) gif_frame_delays_[i] = 100;
                }
            }
            free(property_item);
        }

        std::cout << "[SplashView] GIF detected, frame count: " << gif_frame_count_ << std::endl;
    } else {
        is_gif_ = false;
    }

    delete[] dimension_ids;
}

void SplashView::UpdateGifFrame() {
    if (!is_gif_ || gif_frame_count_ <= 1 || !logo_bitmap_) return;

    // Move to next frame
    gif_current_frame_ = (gif_current_frame_ + 1) % gif_frame_count_;

    // Select the frame in the bitmap
    GUID page_guid = Gdiplus::FrameDimensionTime;
    logo_bitmap_->SelectActiveFrame(&page_guid, gif_current_frame_);

    // Redraw
    InvalidateRect(splash_window_, nullptr, FALSE);

    // Reset timer for next frame's delay
    if (gif_timer_id_) {
        KillTimer(splash_window_, gif_timer_id_);
    }
    UINT delay = gif_frame_delays_ ? gif_frame_delays_[gif_current_frame_] : 100;
    if (delay < 20) delay = 100;
    gif_timer_id_ = SetTimer(splash_window_, kGifTimerId, delay, nullptr);
}

void SplashView::StartAnimation() {
    if (!splash_window_ || is_animating_) {
        return;
    }

    is_animating_ = true;

    // Initialize and start GIF animation if it's a GIF
    if (is_gif_ && gif_frame_count_ > 1) {
        // Start GIF frame timer with first frame's delay
        UINT delay = gif_frame_delays_ ? gif_frame_delays_[0] : 100;
        if (delay < 20) delay = 100;  // Minimum delay
        gif_timer_id_ = SetTimer(splash_window_, kGifTimerId, delay, nullptr);
        std::cout << "[SplashView] Started GIF animation, frames: " << gif_frame_count_ << std::endl;
    }
    // Note: Breathing animation removed - logo stays static (scale = 1.0)

    // Start progress animation timer if enabled
    if (show_progress_bar) {
        progress_timer_id_ = SetTimer(splash_window_, kProgressTimerId, kProgressInterval, nullptr);
    }
}

void SplashView::ResizeToParent() {
    if (!splash_window_ || !parent_window_) return;

    RECT parent_rect;
    GetClientRect(parent_window_, &parent_rect);
    int width = parent_rect.right - parent_rect.left;
    int height = parent_rect.bottom - parent_rect.top;

    // Resize splash to cover entire parent client area
    SetWindowPos(splash_window_, HWND_TOP, 0, 0, width, height, SWP_SHOWWINDOW);
    InvalidateRect(splash_window_, nullptr, FALSE);

    std::cout << "[SplashView] Resized to parent: " << width << "x" << height << std::endl;
}

void SplashView::Hide(std::function<void()> completion) {
    OutputDebugStringW(L"[SplashView] Hide() called\n");
    std::cout << "[SplashView] Hide() called" << std::endl;
    hide_completion_ = completion;

    // Stop animation timers
    if (animation_timer_id_) {
        KillTimer(splash_window_, animation_timer_id_);
        animation_timer_id_ = 0;
    }
    if (progress_timer_id_) {
        KillTimer(splash_window_, progress_timer_id_);
        progress_timer_id_ = 0;
    }
    if (gif_timer_id_) {
        KillTimer(splash_window_, gif_timer_id_);
        gif_timer_id_ = 0;
    }

    // Complete progress bar to 100%
    current_progress_ = 1.0;
    InvalidateRect(splash_window_, nullptr, FALSE);

    // Start fade out animation
    std::cout << "[SplashView] Starting fade out animation..." << std::endl;
    fade_timer_id_ = SetTimer(splash_window_, kFadeTimerId, kFadeInterval, nullptr);
    if (fade_timer_id_ == 0) {
        // Timer failed, hide immediately as fallback
        std::cout << "[SplashView] WARNING: SetTimer failed, hiding immediately" << std::endl;
        ShowWindow(splash_window_, SW_HIDE);
        is_animating_ = false;
        is_visible_ = false;
    }
}

LRESULT CALLBACK SplashView::WindowProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
    SplashView* view = nullptr;

    if (message == WM_CREATE) {
        CREATESTRUCT* cs = reinterpret_cast<CREATESTRUCT*>(lparam);
        view = static_cast<SplashView*>(cs->lpCreateParams);
        SetWindowLongPtr(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(view));
    } else {
        view = reinterpret_cast<SplashView*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));
    }

    if (view) {
        return view->HandleMessage(hwnd, message, wparam, lparam);
    }

    return DefWindowProc(hwnd, message, wparam, lparam);
}

LRESULT SplashView::HandleMessage(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
    switch (message) {
        case WM_PAINT:
            OnPaint();
            return 0;

        case WM_TIMER:
            if (wparam == kBreathingTimerId) {
                // Breathing animation disabled
            } else if (wparam == kProgressTimerId) {
                UpdateProgressAnimation();
            } else if (wparam == kFadeTimerId) {
                OutputDebugStringW(L"[SplashView] WM_TIMER(kFadeTimerId) received\n");
                PerformFadeOut();
            } else if (wparam == kGifTimerId) {
                UpdateGifFrame();
            }
            return 0;

        case WM_SIZE: {
            // Redraw on resize
            InvalidateRect(hwnd, nullptr, FALSE);
            return 0;
        }

        case WM_ERASEBKGND:
            // Prevent flickering by handling background erase in WM_PAINT
            return 1;
    }

    return DefWindowProc(hwnd, message, wparam, lparam);
}

void SplashView::OnPaint() {
    PAINTSTRUCT ps;
    HDC hdc = BeginPaint(splash_window_, &ps);

    RECT client_rect;
    GetClientRect(splash_window_, &client_rect);
    int width = client_rect.right - client_rect.left;
    int height = client_rect.bottom - client_rect.top;

    // Create double buffer to prevent flickering
    HDC memDC = CreateCompatibleDC(hdc);
    HBITMAP memBitmap = CreateCompatibleBitmap(hdc, width, height);
    HBITMAP oldBitmap = (HBITMAP)SelectObject(memDC, memBitmap);

    // Create GDI+ graphics object
    Gdiplus::Graphics graphics(memDC);
    graphics.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
    graphics.SetInterpolationMode(Gdiplus::InterpolationModeHighQualityBicubic);

    // Draw all elements
    DrawBackground(graphics);
    DrawLogo(graphics);
    if (show_progress_bar) {
        DrawProgressBar(graphics);
    }

    // Copy double buffer to screen
    BitBlt(hdc, 0, 0, width, height, memDC, 0, 0, SRCCOPY);

    // Cleanup
    SelectObject(memDC, oldBitmap);
    DeleteObject(memBitmap);
    DeleteDC(memDC);

    EndPaint(splash_window_, &ps);
}

void SplashView::DrawBackground(Gdiplus::Graphics& g) {
    RECT client_rect;
    GetClientRect(splash_window_, &client_rect);

    // Fill with amber background color
    Gdiplus::SolidBrush brush(Gdiplus::Color(255, 255, 248, 225));  // #FFF8E1
    g.FillRectangle(&brush, 0, 0,
                    client_rect.right - client_rect.left,
                    client_rect.bottom - client_rect.top);
}

void SplashView::DrawLogo(Gdiplus::Graphics& g) {
    if (!logo_bitmap_ || logo_bitmap_->GetLastStatus() != Gdiplus::Ok) {
        return;
    }

    RECT client_rect;
    GetClientRect(splash_window_, &client_rect);
    int window_width = client_rect.right - client_rect.left;
    int window_height = client_rect.bottom - client_rect.top;

    // Calculate logo size with DPI scaling and breathing animation
    int base_size = static_cast<int>(kLogoSize * dpi_scale_);
    int scaled_size = static_cast<int>(base_size * logo_scale_);

    // Center the logo
    int x = (window_width - scaled_size) / 2;
    int y = (window_height - scaled_size) / 2;

    // Offset logo slightly upward if progress bar is shown
    if (show_progress_bar) {
        y -= static_cast<int>((kProgressBarTopMargin + kProgressBarHeight) * dpi_scale_ / 2);
    }

    // Draw logo
    g.DrawImage(logo_bitmap_.get(), x, y, scaled_size, scaled_size);
}

void SplashView::DrawProgressBar(Gdiplus::Graphics& g) {
    RECT client_rect;
    GetClientRect(splash_window_, &client_rect);
    int window_width = client_rect.right - client_rect.left;
    int window_height = client_rect.bottom - client_rect.top;

    // Calculate progress bar dimensions with DPI scaling
    int bar_width = static_cast<int>(kProgressBarWidth * dpi_scale_);
    int bar_height = static_cast<int>(kProgressBarHeight * dpi_scale_);
    int top_margin = static_cast<int>(kProgressBarTopMargin * dpi_scale_);
    int logo_size = static_cast<int>(kLogoSize * dpi_scale_);

    // Position below the logo
    int x = (window_width - bar_width) / 2;
    int y = (window_height + logo_size) / 2 + top_margin;

    // Adjust for the logo offset
    if (show_progress_bar) {
        y -= static_cast<int>((kProgressBarTopMargin + kProgressBarHeight) * dpi_scale_ / 2);
    }

    // Draw track (background)
    Gdiplus::SolidBrush track_brush(Gdiplus::Color(255, 245, 224, 178));  // Amber light
    int corner_radius = bar_height / 2;

    // Create rounded rectangle path for track
    Gdiplus::GraphicsPath track_path;
    track_path.AddArc(x, y, corner_radius * 2, bar_height, 180, 90);
    track_path.AddArc(x + bar_width - corner_radius * 2, y, corner_radius * 2, bar_height, 270, 90);
    track_path.AddArc(x + bar_width - corner_radius * 2, y, corner_radius * 2, bar_height, 0, 90);
    track_path.AddArc(x, y, corner_radius * 2, bar_height, 90, 90);
    track_path.CloseFigure();
    g.FillPath(&track_brush, &track_path);

    // Draw progress (filled portion)
    if (current_progress_ > 0) {
        int progress_width = static_cast<int>(bar_width * current_progress_);
        if (progress_width > corner_radius * 2) {
            Gdiplus::SolidBrush progress_brush(Gdiplus::Color(255, 245, 166, 35));  // #F5A623

            Gdiplus::GraphicsPath progress_path;
            progress_path.AddArc(x, y, corner_radius * 2, bar_height, 180, 90);
            progress_path.AddArc(x + progress_width - corner_radius * 2, y, corner_radius * 2, bar_height, 270, 90);
            progress_path.AddArc(x + progress_width - corner_radius * 2, y, corner_radius * 2, bar_height, 0, 90);
            progress_path.AddArc(x, y, corner_radius * 2, bar_height, 90, 90);
            progress_path.CloseFigure();
            g.FillPath(&progress_brush, &progress_path);
        }
    }
}

void SplashView::UpdateBreathingAnimation() {
    // Breathing animation disabled - logo stays at scale 1.0
    // This function is kept for compatibility but does nothing
}

void SplashView::UpdateProgressAnimation() {
    // Progress smoothly from 0 to ~80%, then wait for hide() to complete to 100%
    if (current_progress_ < 0.8) {
        // Use easing function for smooth progress
        double remaining = 0.8 - current_progress_;
        current_progress_ += remaining * 0.05;
    }

    // Trigger repaint
    InvalidateRect(splash_window_, nullptr, FALSE);
}

void SplashView::PerformFadeOut() {
    // Calculate alpha decrement based on transition duration
    int steps = static_cast<int>(transition_duration * 1000 / kFadeInterval);
    int alpha_step = std::max(1, 255 / std::max(1, steps));

    if (current_alpha_ > alpha_step) {
        current_alpha_ -= static_cast<BYTE>(alpha_step);
        SetLayeredWindowAttributes(splash_window_, 0, current_alpha_, LWA_ALPHA);
    } else {
        // Fade complete
        std::cout << "[SplashView] Fade animation complete" << std::endl;
        current_alpha_ = 0;
        KillTimer(splash_window_, fade_timer_id_);
        fade_timer_id_ = 0;

        // Hide the window
        ShowWindow(splash_window_, SW_HIDE);
        is_animating_ = false;
        is_visible_ = false;  // Update internal visibility flag
        std::cout << "[SplashView] Window hidden with fade effect" << std::endl;
    }
}
