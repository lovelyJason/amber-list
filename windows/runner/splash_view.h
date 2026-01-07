#ifndef RUNNER_SPLASH_VIEW_H_
#define RUNNER_SPLASH_VIEW_H_

#include <windows.h>
#include <gdiplus.h>
#include <functional>
#include <memory>

#pragma comment(lib, "gdiplus.lib")

/// Splash screen transition effect type
enum class SplashTransitionType {
    kFadeOut,        // Simple fade out
    kCrossDissolve   // Cross dissolve with Flutter view
};

/// Native splash screen view for Windows
/// Displays amber-themed logo with breathing animation and optional progress bar
/// while Flutter engine initializes
///
/// Design:
/// - Background: Amber light color (#FFF8E1)
/// - Logo: mosquito_amber.png with breathing animation
/// - Progress bar: Optional, shows loading indicator
///
/// Usage:
/// 1. Create SplashView attached to parent window
/// 2. Call StartAnimation() to begin
/// 3. Call Hide() when Flutter is ready (first frame rendered)
class SplashView {
public:
    // Configuration
    static SplashTransitionType transition_type;
    static double transition_duration;  // seconds
    static bool show_progress_bar;

    /// Constructor
    /// @param parent_window Parent window handle
    SplashView(HWND parent_window);
    ~SplashView();

    /// Create and show the splash view
    bool Create();

    /// Start animations (breathing logo + progress bar)
    void StartAnimation();

    /// Hide splash with transition effect
    /// @param completion Callback when transition completes
    void Hide(std::function<void()> completion = nullptr);

    /// Check if splash window exists and is visible
    /// Note: Don't use IsWindowVisible() for child windows - it returns false if parent is hidden
    bool IsVisible() const { return splash_window_ != nullptr && is_visible_; }

    /// Get splash window handle
    HWND GetHandle() const { return splash_window_; }

    /// Resize splash to match parent window client area
    void ResizeToParent();

private:
    // Window procedure
    static LRESULT CALLBACK WindowProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);
    LRESULT HandleMessage(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);

    // Drawing
    void OnPaint();
    void DrawBackground(Gdiplus::Graphics& g);
    void DrawLogo(Gdiplus::Graphics& g);
    void DrawProgressBar(Gdiplus::Graphics& g);

    // Animation
    void UpdateBreathingAnimation();
    void UpdateProgressAnimation();
    void PerformFadeOut();

    // Load logo from Flutter assets
    bool LoadLogoImage();

    // Register window class
    static bool RegisterWindowClass();

    // Member variables
    HWND parent_window_;
    HWND splash_window_ = nullptr;
    float dpi_scale_ = 1.0f;

    // Logo
    std::unique_ptr<Gdiplus::Bitmap> logo_bitmap_;
    float logo_scale_ = 1.0f;
    bool scale_increasing_ = true;

    // GIF animation support
    bool is_gif_ = false;
    UINT gif_frame_count_ = 0;
    UINT gif_current_frame_ = 0;
    UINT* gif_frame_delays_ = nullptr;  // Frame delays in milliseconds
    UINT_PTR gif_timer_id_ = 0;

    // Progress
    double current_progress_ = 0.0;

    // Animation state
    bool is_animating_ = false;
    bool is_visible_ = false;  // Track visibility internally (Win32 API unreliable for child windows)
    UINT_PTR animation_timer_id_ = 0;
    UINT_PTR progress_timer_id_ = 0;
    UINT_PTR fade_timer_id_ = 0;

    // GIF frame switching
    void UpdateGifFrame();
    void InitGifAnimation();

    // Fade out state
    BYTE current_alpha_ = 255;
    std::function<void()> hide_completion_;

    // Colors (Amber theme)
    static const COLORREF kBackgroundColor = RGB(255, 248, 225);  // #FFF8E1
    static const COLORREF kProgressTrackColor = RGB(245, 224, 178);  // Amber light
    static const COLORREF kProgressTintColor = RGB(245, 166, 35);  // #F5A623

    // Layout constants
    static const int kLogoSize = 120;
    static const int kProgressBarWidth = 160;
    static const int kProgressBarHeight = 6;
    static const int kProgressBarTopMargin = 30;

    // Static members
    static const wchar_t* kWindowClassName;
    static bool class_registered_;

    // GDI+ token
    static ULONG_PTR gdiplus_token_;
    static bool gdiplus_initialized_;
};

#endif  // RUNNER_SPLASH_VIEW_H_
