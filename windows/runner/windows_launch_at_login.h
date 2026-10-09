#ifndef RUNNER_WINDOWS_LAUNCH_AT_LOGIN_H_
#define RUNNER_WINDOWS_LAUNCH_AT_LOGIN_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>

// Owns login registration and the window preference used by its command line.
class WindowsLaunchAtLogin final {
public:
  explicit WindowsLaunchAtLogin(flutter::BinaryMessenger *messenger);
  ~WindowsLaunchAtLogin();

  WindowsLaunchAtLogin(const WindowsLaunchAtLogin &) = delete;
  WindowsLaunchAtLogin &operator=(const WindowsLaunchAtLogin &) = delete;

  // Also called by trusttunnel/windows_main_window for the window preference.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

private:
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif // RUNNER_WINDOWS_LAUNCH_AT_LOGIN_H_
