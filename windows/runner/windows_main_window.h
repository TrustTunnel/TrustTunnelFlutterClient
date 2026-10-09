#ifndef RUNNER_WINDOWS_MAIN_WINDOW_H_
#define RUNNER_WINDOWS_MAIN_WINDOW_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <functional>
#include <memory>
#include <optional>

// Shared by second-instance activation and the tray's primary click.
// Register the same name in the tray plugin without depending on runner headers.
const UINT kActivateMainWindow =
    RegisterWindowMessageW(L"TrustTunnel.ActivateMainWindow");
constexpr UINT kMainWindowFrameReady = WM_APP + 0x55;

enum class LaunchMode { kManual, kAutostartWindow, kAutostartTray };

class WindowsLaunchAtLogin;

class WindowsMainWindow {
public:
  using AwaitFrame = std::function<void()>;
  WindowsMainWindow(flutter::BinaryMessenger *messenger, HWND window,
                    AwaitFrame await_frame, LaunchMode launch_mode,
                    WindowsLaunchAtLogin& launch_at_login);
  ~WindowsMainWindow();
  std::optional<LRESULT> HandleMessage(UINT message, WPARAM wparam,
                                       LPARAM lparam);

private:
  void Show();
  void Hide();
  void PickLogExportPath(
      const flutter::EncodableMap &arguments,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void TryShow();
  void WaitForTray();
  void CancelTrayWait();
  void PrepareToExit();
  HWND window_;
  AwaitFrame await_frame_;
  WindowsLaunchAtLogin& launch_at_login_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  bool tray_available_ = false;
  UINT_PTR tray_wait_timer_ = 0;
  bool exiting_ = false;
  bool configured_ = false;
  bool launch_complete_ = false;
  bool frame_ready_ = false;
  bool show_requested_;
};

#endif
