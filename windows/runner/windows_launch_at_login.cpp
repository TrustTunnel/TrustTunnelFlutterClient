#include "windows_launch_at_login.h"

#include <windows.h>

#include <flutter/standard_method_codec.h>

#include <cstdint>
#include <string>
#include <utility>
#include <variant>

#include "../user_context/launch_at_login_registry.h"

WindowsLaunchAtLogin::WindowsLaunchAtLogin(flutter::BinaryMessenger *messenger)
    : channel_(
          std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
              messenger, "trusttunnel/launch_at_login",
              &flutter::StandardMethodCodec::GetInstance())) {
  channel_->SetMethodCallHandler([this](const auto &call, auto result) {
    HandleMethodCall(call, std::move(result));
  });
}

WindowsLaunchAtLogin::~WindowsLaunchAtLogin() {
  channel_->SetMethodCallHandler(nullptr);
}

void WindowsLaunchAtLogin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto &method = call.method_name();
  const bool is_getter =
      method == "isEnabled" || method == "getOpenMainWindowOnLogin";
  const bool is_setter =
      method == "setEnabled" || method == "setOpenMainWindowOnLogin";
  if (!is_getter && !is_setter) {
    result->NotImplemented();
    return;
  }

  bool enabled = false;
  if (is_setter) {
    const auto *arguments =
        call.arguments() ? std::get_if<flutter::EncodableMap>(call.arguments())
                         : nullptr;
    const bool *value = nullptr;
    if (arguments != nullptr) {
      const auto item = arguments->find(flutter::EncodableValue("enabled"));
      if (item != arguments->end()) {
        value = std::get_if<bool>(&item->second);
      }
    }
    if (value == nullptr) {
      result->Error("argument-error", "Expected a boolean enabled argument");
      return;
    }
    enabled = *value;
  }

  LSTATUS status;
  if (method == "isEnabled") {
    status = windows_launch_at_login::ReadEnabled(HKEY_CURRENT_USER, enabled);
  } else if (method == "setEnabled") {
    status = windows_launch_at_login::SetEnabled(HKEY_CURRENT_USER, enabled);
  } else if (method == "getOpenMainWindowOnLogin") {
    status = windows_launch_at_login::ReadWindowPreference(HKEY_CURRENT_USER,
                                                           enabled);
  } else {
    status = windows_launch_at_login::SetWindowPreference(HKEY_CURRENT_USER,
                                                          enabled);
  }
  if (status != ERROR_SUCCESS) {
    const bool too_long = status == ERROR_FILENAME_EXCED_RANGE;
    result->Error(too_long ? "autostart-command-too-long" : "registry-error",
                  too_long
                      ? "The login command exceeds the Windows Run limit of "
                        "260 characters"
                      : "Failed to access Windows login settings: " + method,
                  flutter::EncodableValue(static_cast<int64_t>(status)));
    return;
  }
  if (is_getter) {
    result->Success(flutter::EncodableValue(enabled));
  } else {
    result->Success();
  }
}
