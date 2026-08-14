#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

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
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "jellyfinitive/window",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        HandleWindowMethodCall(call, std::move(result));
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::HandleWindowMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = method_call.method_name();
  if (method == "setFullscreen") {
    bool fullscreen = false;
    const auto* arguments = method_call.arguments();
    if (arguments != nullptr) {
      const auto* map = std::get_if<flutter::EncodableMap>(arguments);
      if (map != nullptr) {
        const auto it = map->find(flutter::EncodableValue("fullscreen"));
        if (it != map->end()) {
          fullscreen = std::get<bool>(it->second);
        }
      }
    }
    SetFullscreen(fullscreen);
    result->Success(flutter::EncodableValue(true));
  } else if (method == "isFullscreen") {
    result->Success(flutter::EncodableValue(is_fullscreen_));
  } else {
    result->NotImplemented();
  }
}

void FlutterWindow::SetFullscreen(bool fullscreen) {
  if (fullscreen == is_fullscreen_) {
    return;
  }
  HWND hwnd = GetHandle();
  if (hwnd == nullptr) {
    return;
  }

  if (fullscreen) {
    // Save the current placement & style so they can be restored.
    saved_placement_.length = sizeof(WINDOWPLACEMENT);
    ::GetWindowPlacement(hwnd, &saved_placement_);
    saved_style_ = static_cast<LONG>(::GetWindowLongPtr(hwnd, GWL_STYLE));

    // Remove the frame: title bar, thick border & min/max buttons.
    LONG style = saved_style_;
    style &= ~(WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX |
               WS_SYSMENU);
    ::SetWindowLongPtr(hwnd, GWL_STYLE, style);

    // Cover the whole monitor (including the taskbar area).
    MONITORINFO monitor = {};
    monitor.cbSize = sizeof(MONITORINFO);
    ::GetMonitorInfo(::MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST),
                     &monitor);
    ::SetWindowPos(
        hwnd, HWND_TOP, monitor.rcMonitor.left, monitor.rcMonitor.top,
        monitor.rcMonitor.right - monitor.rcMonitor.left,
        monitor.rcMonitor.bottom - monitor.rcMonitor.top,
        SWP_FRAMECHANGED | SWP_NOOWNERZORDER | SWP_SHOWWINDOW);
    is_fullscreen_ = true;
  } else {
    // Restore the original frame.
    ::SetWindowLongPtr(hwnd, GWL_STYLE, saved_style_);
    ::SetWindowPlacement(hwnd, &saved_placement_);
    ::SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
                   SWP_FRAMECHANGED | SWP_NOACTIVATE | SWP_NOMOVE |
                       SWP_NOSIZE | SWP_NOZORDER | SWP_NOOWNERZORDER);
    is_fullscreen_ = false;
  }
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
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
