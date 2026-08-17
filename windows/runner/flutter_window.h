#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>

#include "win32_window.h"

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
  // Handles method calls from the Dart side on the "fynitiv/window"
  // channel (fullscreen control).
  void HandleWindowMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Puts/restores the window to true fullscreen (hides the OS title bar and
  // covers the whole monitor).
  void SetFullscreen(bool fullscreen);

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Method channel used to control the native window from Dart.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;

  // State saved while in fullscreen so it can be restored.
  bool is_fullscreen_ = false;
  WINDOWPLACEMENT saved_placement_{};
  LONG saved_style_ = 0;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
