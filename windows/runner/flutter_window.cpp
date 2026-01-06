#include "flutter_window.h"

#include <optional>
#include <iostream>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"
#include "sticky_note_manager.h"
#include "native_window_manager.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  // Register native sticky note manager's Platform Channel
  StickyNoteManager::GetInstance().Setup(flutter_controller_->engine());

  // Register unified native window manager (for QuickAdd, etc.)
  NativeWindowManager::GetInstance().Setup(flutter_controller_->engine());

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Setup splash screen AFTER setting Flutter view as child, so splash is on top
  SetupSplashView();

  // Setup Platform Channel for splash control AFTER Flutter view is set up
  // This ensures the channel is ready when Flutter calls hideSplash()
  SetupSplashChannel();

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
    // Resize splash to match final window size after Show()
    if (splash_view_) {
      splash_view_->ResizeToParent();
    }
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::SetupSplashView() {
  // Create splash view as overlay on top of Flutter view
  splash_view_ = std::make_unique<SplashView>(GetHandle());
  if (splash_view_->Create()) {
    splash_view_->StartAnimation();
  }
}

void FlutterWindow::SetupSplashChannel() {
  // Create channel and store as member to keep it alive
  splash_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "com.amberlist.splash",
      &flutter::StandardMethodCodec::GetInstance());

  OutputDebugStringW(L"[Splash] SetupSplashChannel called\n");
  std::cout << "[Splash] SetupSplashChannel called" << std::endl;

  splash_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        OutputDebugStringW(L"[Splash] Method call received\n");
        std::cout << "[Splash] Method call received: " << call.method_name() << std::endl;
        if (call.method_name() == "hideSplash") {
          OutputDebugStringW(L"[Splash] hideSplash called\n");
          std::cout << "[Splash] hideSplash method called - hiding splash now" << std::endl;
          HideSplash();
          result->Success();
          std::cout << "[Splash] hideSplash completed successfully" << std::endl;
        } else if (call.method_name() == "showSplash") {
          // Debug: Show splash screen again
          std::cout << "[Splash] showSplash method called" << std::endl;
          int duration = 3000;  // default 3 seconds
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (args) {
            auto duration_it = args->find(flutter::EncodableValue("duration"));
            if (duration_it != args->end()) {
              const auto* dur = std::get_if<int>(&duration_it->second);
              if (dur) duration = *dur;
            }
          }
          ShowSplash(duration);
          result->Success();
          std::cout << "[Splash] showSplash completed, duration: " << duration << "ms" << std::endl;
        } else if (call.method_name() == "configureSplash") {
          // Allow Flutter to configure splash options
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (args) {
            auto transition_it = args->find(flutter::EncodableValue("transitionType"));
            if (transition_it != args->end()) {
              const auto* transition_type = std::get_if<std::string>(&transition_it->second);
              if (transition_type) {
                SplashView::transition_type = (*transition_type == "crossDissolve")
                    ? SplashTransitionType::kCrossDissolve
                    : SplashTransitionType::kFadeOut;
              }
            }

            auto duration_it = args->find(flutter::EncodableValue("transitionDuration"));
            if (duration_it != args->end()) {
              const auto* duration = std::get_if<double>(&duration_it->second);
              if (duration) {
                SplashView::transition_duration = *duration;
              }
            }

            auto progress_it = args->find(flutter::EncodableValue("showProgressBar"));
            if (progress_it != args->end()) {
              const auto* show_progress = std::get_if<bool>(&progress_it->second);
              if (show_progress) {
                SplashView::show_progress_bar = *show_progress;
              }
            }
          }
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
}

void FlutterWindow::ShowSplash(int duration_ms) {
  std::cout << "[Splash] ShowSplash() called, duration: " << duration_ms << "ms" << std::endl;

  // If splash already exists and visible, just reset timer
  if (splash_view_ && splash_view_->IsVisible()) {
    std::cout << "[Splash] Splash already visible, skipping" << std::endl;
    return;
  }

  // Create new splash view
  splash_view_ = std::make_unique<SplashView>(GetHandle());
  if (splash_view_->Create()) {
    splash_view_->ResizeToParent();
    splash_view_->StartAnimation();
    std::cout << "[Splash] Splash created and showing" << std::endl;

    // Auto hide after duration
    if (duration_ms > 0) {
      // Use Windows timer for auto-hide
      SetTimer(GetHandle(), 9999, duration_ms, nullptr);  // Timer ID 9999 for splash auto-hide
    }
  } else {
    std::cout << "[Splash] ERROR: Failed to create splash" << std::endl;
    splash_view_.reset();
  }
}

void FlutterWindow::HideSplash() {
  OutputDebugStringW(L"[Splash] HideSplash() called\n");
  std::cout << "[Splash] HideSplash() called" << std::endl;

  if (!splash_view_) {
    OutputDebugStringW(L"[Splash] splash_view_ is null!\n");
    std::cout << "[Splash] ERROR: splash_view_ is null!" << std::endl;
    return;
  }

  // Debug: Check visibility state
  bool isVisible = splash_view_->IsVisible();
  HWND hwnd = splash_view_->GetHandle();
  std::cout << "[Splash] splash_view_ handle: " << hwnd
            << ", IsVisible(): " << (isVisible ? "true" : "false") << std::endl;

  // Always try to hide, even if IsVisible returns false (child window quirk)
  OutputDebugStringW(L"[Splash] Starting fade out...\n");
  std::cout << "[Splash] Starting fade out..." << std::endl;

  // Start fade animation - splash_view_ will be kept alive until window is destroyed
  // The fade animation runs asynchronously via WM_TIMER, so we don't reset here.
  // The SplashView destructor will clean up when FlutterWindow is destroyed.
  splash_view_->Hide(nullptr);
  std::cout << "[Splash] Fade animation started" << std::endl;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_SIZE:
      // Resize splash to match window when parent resizes
      if (splash_view_ && splash_view_->IsVisible()) {
        splash_view_->ResizeToParent();
      }
      break;
    case WM_TIMER:
      // Handle splash auto-hide timer
      if (wparam == 9999) {
        KillTimer(hwnd, 9999);
        std::cout << "[Splash] Auto-hide timer fired" << std::endl;
        HideSplash();
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
