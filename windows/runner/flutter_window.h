#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>

#include "win32_window.h"
#include "splash_view.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // Setup splash screen overlay
  void SetupSplashView();

  // Setup Platform Channel for splash control from Flutter
  void SetupSplashChannel();

  // Show splash screen (for debugging)
  void ShowSplash(int duration_ms);

  // Hide splash screen with transition
  void HideSplash();

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Native splash view displayed during Flutter engine initialization
  std::unique_ptr<SplashView> splash_view_;

  // Platform Channel for splash control (must be kept alive)
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> splash_channel_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
