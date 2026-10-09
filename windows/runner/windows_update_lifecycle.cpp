#include "windows_update_lifecycle.h"

#include <flutter/standard_method_codec.h>

#include <cstdlib>

namespace {
constexpr wchar_t kInstallationLock[] = L"Global\\TrustTunnel.Installation";
constexpr UINT_PTR kInstallerPollTimer = 0x5455;
const UINT kExitForUpdate =
    RegisterWindowMessageW(L"TrustTunnel.ExitForUpdate");
} // namespace

bool IsTrustTunnelInstallationActive() {
  HANDLE lock = OpenMutexW(SYNCHRONIZE, FALSE, kInstallationLock);
  if (lock) {
    CloseHandle(lock);
    return true;
  }
  // Fail closed if an installer in another security context owns the lock.
  return GetLastError() != ERROR_FILE_NOT_FOUND;
}

WindowsUpdateLifecycle::WindowsUpdateLifecycle(
    flutter::BinaryMessenger *messenger, HWND window)
    : window_(window),
      channel_(
          std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
              messenger, "trusttunnel/windows_update",
              &flutter::StandardMethodCodec::GetInstance())) {
  channel_->SetMethodCallHandler([this](const auto &call, auto result) {
    if (call.method_name() == "ready") {
      dart_ready_ = true;
      result->Success();
      if (exit_requested_ && !exit_delivered_) {
        exit_delivered_ = true;
        channel_->InvokeMethod("exitForUpdate", nullptr);
      }
    } else if (call.method_name() == "completeExit") {
      if (!exit_requested_ ||
          (shutdown_installer_ &&
           WaitForSingleObject(shutdown_installer_, 0) != WAIT_TIMEOUT) ||
          !IsTrustTunnelInstallationActive()) {
        result->Error("update-not-ready", "Setup has not requested shutdown");
        return;
      }
      result->Success();
      // Do not route through WM_CLOSE: that can hide the window or invoke the
      // normal VPN disconnect dialog. Engine destruction detaches the service.
      PostQuitMessage(EXIT_SUCCESS);
    } else {
      result->NotImplemented();
    }
  });
}

WindowsUpdateLifecycle::~WindowsUpdateLifecycle() {
  channel_->SetMethodCallHandler(nullptr);
  KillTimer(window_, kInstallerPollTimer);
  if (shutdown_installer_)
    CloseHandle(shutdown_installer_);
}

std::optional<LRESULT>
WindowsUpdateLifecycle::HandleMessage(UINT message, WPARAM wparam,
                                      LPARAM /*lparam*/) {
  if (message == WM_TIMER && wparam == kInstallerPollTimer) {
    if (exit_requested_ &&
        (!IsTrustTunnelInstallationActive() ||
         (shutdown_installer_ &&
          WaitForSingleObject(shutdown_installer_, 0) == WAIT_OBJECT_0))) {
      if (shutdown_installer_)
        CloseHandle(shutdown_installer_);
      shutdown_installer_ = nullptr;
      exit_requested_ = false;
      exit_delivered_ = false;
      KillTimer(window_, kInstallerPollTimer);
      channel_->InvokeMethod("shutdownCancelled", nullptr);
    }
    return 0;
  }
  if (exit_requested_ &&
      (message == WM_CLOSE ||
       (message == WM_SYSCOMMAND && (wparam & 0xfff0) == SC_CLOSE)))
    return 0;
  if (kExitForUpdate && message == kExitForUpdate) {
    if (!IsTrustTunnelInstallationActive())
      return 0;
    if (!exit_requested_) {
      shutdown_installer_ =
          OpenProcess(SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION, FALSE,
                      static_cast<DWORD>(wparam));
      DWORD session = 0;
      DWORD own_session = 0;
      if (!ProcessIdToSessionId(static_cast<DWORD>(wparam), &session) ||
          !ProcessIdToSessionId(GetCurrentProcessId(), &own_session) ||
          session != own_session) {
        if (shutdown_installer_)
          CloseHandle(shutdown_installer_);
        shutdown_installer_ = nullptr;
        return 0;
      }
      // With credential UAC, the caller may not be allowed to open the admin
      // process. The global installation lock still provides crash-safe
      // liveness when the process handle is unavailable.
      if (!SetTimer(window_, kInstallerPollTimer, 250, nullptr)) {
        // Without cancellation polling, a timed-out setup could leave Dart
        // frozen. Decline the request and let setup's process wait time out.
        if (shutdown_installer_)
          CloseHandle(shutdown_installer_);
        shutdown_installer_ = nullptr;
        return 0;
      }
    }
    exit_requested_ = true;
    if (dart_ready_ && !exit_delivered_) {
      exit_delivered_ = true;
      channel_->InvokeMethod("exitForUpdate", nullptr);
    }
    return 0;
  }
  return std::nullopt;
}
