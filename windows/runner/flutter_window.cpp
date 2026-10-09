#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject &project,
                             LaunchMode launch_mode)
    : project_(project), launch_mode_(launch_mode) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (IsTrustTunnelInstallationActive()) return false;
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

  windows_exit_dialog_ = std::make_unique<WindowsExitDialog>(
      flutter_controller_->engine()->messenger(), GetHandle());

  launch_at_login_ = std::make_unique<WindowsLaunchAtLogin>(
      flutter_controller_->engine()->messenger());

  main_window_ = std::make_unique<WindowsMainWindow>(
      flutter_controller_->engine()->messenger(), GetHandle(),
      [this]() {
        const HWND window = GetHandle();
        flutter_controller_->engine()->SetNextFrameCallback([window]() {
          // Engine frame callbacks need not run on the window's UI thread.
          PostMessage(window, kMainWindowFrameReady, 0, 0);
        });
        flutter_controller_->ForceRedraw();
      },
      launch_mode_, *launch_at_login_);

  update_lifecycle_ = std::make_unique<WindowsUpdateLifecycle>(
      flutter_controller_->engine()->messenger(), GetHandle());
  return true;
}

void FlutterWindow::OnDestroy() {
  update_lifecycle_.reset();
  main_window_.reset();
  launch_at_login_.reset();
  windows_exit_dialog_.reset();

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (update_lifecycle_) {
    const auto result = update_lifecycle_->HandleMessage(message, wparam, lparam);
    if (result) return *result;
  }
  if (message == WM_ENDSESSION && flutter_controller_) {
    // Mark exit before plugins remove the tray, then let them enqueue cleanup
    // before the message loop returns and tears down the engine.
    if (main_window_)
      main_window_->HandleMessage(message, wparam, lparam);
    flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam, lparam);
    return 0;
  }
  if (main_window_) {
    const auto result = main_window_->HandleMessage(message, wparam, lparam);
    if (result) return *result;
  }
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
