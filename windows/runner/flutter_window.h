#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <memory>

#include "win32_window.h"
#include "windows_exit_dialog.h"
#include "windows_launch_at_login.h"
#include "windows_main_window.h"
#include "windows_update_lifecycle.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
   FlutterWindow(const flutter::DartProject &project, LaunchMode launch_mode);
   virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;
  LaunchMode launch_mode_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  std::unique_ptr<WindowsExitDialog> windows_exit_dialog_;
  std::unique_ptr<WindowsLaunchAtLogin> launch_at_login_;
  std::unique_ptr<WindowsMainWindow> main_window_;
  std::unique_ptr<WindowsUpdateLifecycle> update_lifecycle_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
