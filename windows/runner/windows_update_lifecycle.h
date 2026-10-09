#ifndef RUNNER_WINDOWS_UPDATE_LIFECYCLE_H_
#define RUNNER_WINDOWS_UPDATE_LIFECYCLE_H_

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>
#include <optional>

// Must match ApplicationLifecycle.iss. Opening, rather than owning, this
// mutex checks the lifetime of setup/uninstall across Windows sessions.
bool IsTrustTunnelInstallationActive();

class WindowsUpdateLifecycle {
public:
  WindowsUpdateLifecycle(flutter::BinaryMessenger *messenger, HWND window);
  ~WindowsUpdateLifecycle();
  std::optional<LRESULT> HandleMessage(UINT message, WPARAM wparam,
                                       LPARAM lparam);

private:
  HWND window_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HANDLE shutdown_installer_ = nullptr;
  bool dart_ready_ = false;
  bool exit_requested_ = false;
  bool exit_delivered_ = false;
};

#endif
