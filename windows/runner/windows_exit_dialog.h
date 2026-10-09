// This is a WIP version; it does not need to be reviewed and is entirely temporary.
// At the time of creation, there is no design or technical specification for the final version of the dialog.
#ifndef RUNNER_WINDOWS_EXIT_DIALOG_H_
#define RUNNER_WINDOWS_EXIT_DIALOG_H_

#include <flutter/binary_messenger.h>
#include <windows.h>

#include <memory>

// Owns the platform channel and presents the native confirmation dialog used
// when the application is closed while the VPN is active.
class WindowsExitDialog final {
 public:
  WindowsExitDialog(flutter::BinaryMessenger* messenger, HWND parent_window);
  ~WindowsExitDialog();

  WindowsExitDialog(const WindowsExitDialog&) = delete;
  WindowsExitDialog& operator=(const WindowsExitDialog&) = delete;

 private:
  class Impl;
  std::unique_ptr<Impl> impl_;
};

#endif  // RUNNER_WINDOWS_EXIT_DIALOG_H_
