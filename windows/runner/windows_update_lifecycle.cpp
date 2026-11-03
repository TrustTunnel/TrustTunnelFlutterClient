#include "windows_update_lifecycle.h"

#include <flutter/standard_method_codec.h>

#include <cstdlib>
#include <stdexcept>

namespace {
constexpr wchar_t kInstallationLock[] = L"Global\\TrustTunnel.Installation";
constexpr UINT_PTR kInstallerPollTimer = 0x5455;
constexpr UINT_PTR kLaunchPollTimer = 0x5456;
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
    if (call.method_name() == "createOperation") {
      const bool update_busy =
          launch_ || exit_requested_ || IsTrustTunnelInstallationActive();
      if (update_busy) {
        result->Error("update-busy", "An installer operation is active");
        return;
      }
      try {
        operation_ = CreateUpdateOperation();
        result->Success(flutter::EncodableValue(operation_));
      } catch (const std::exception &error) {
        result->Error("installer-operation", error.what());
      }
    } else if (call.method_name() == "launchInstaller") {
      const bool invalid_operation =
          launch_ || operation_.empty() || !call.arguments() ||
          !std::holds_alternative<flutter::EncodableMap>(*call.arguments());
      if (invalid_operation) {
        result->Error("update-busy", "Invalid installer operation");
        return;
      }
      if (!SetTimer(window_, kLaunchPollTimer, 100, nullptr)) {
        result->Error("installer-launch", "Unable to start launch polling");
        return;
      }
      try {
        launch_ = LaunchWindowsUpdate(
            std::get<flutter::EncodableMap>(*call.arguments()), operation_);
        launch_result_ = std::move(result);
      } catch (const std::exception &error) {
        KillTimer(window_, kLaunchPollTimer);
        result->Error("installer-launch", error.what());
      }
    } else if (call.method_name() == "readResult") {
      try {
        result->Success(ReadWindowsUpdateResult());
      } catch (const std::exception &error) {
        result->Error("installer-result", error.what());
      }
    } else if (call.method_name() == "ready") {
      dart_ready_ = true;
      result->Success();
      if (exit_requested_ && !exit_delivered_) {
        exit_delivered_ = true;
        channel_->InvokeMethod("exitForUpdate", nullptr);
      }
    } else if (call.method_name() == "abortExit") {
      // Setup can keep broadcasting until its shutdown deadline expires.
      // Keep monitoring it, but permit normal window and VPN commands again.
      if (exit_requested_) {
        exit_requested_ = false;
        exit_rejected_ = true;
      }
      result->Success();
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
  KillTimer(window_, kLaunchPollTimer);
  if (launch_) {
    launch_->cancelled = true;
  }
  channel_->SetMethodCallHandler(nullptr);
  KillTimer(window_, kInstallerPollTimer);
  if (shutdown_installer_)
    CloseHandle(shutdown_installer_);
}

std::optional<LRESULT>
WindowsUpdateLifecycle::HandleMessage(UINT message, WPARAM wparam,
                                      LPARAM /*lparam*/) {
  const bool launch_poll = message == WM_TIMER && wparam == kLaunchPollTimer;
  if (launch_poll) {
    if (!launch_) {
      return 0;
    }
    bool completed;
    bool finished;
    std::string error;
    std::string detail;
    {
      std::lock_guard<std::mutex> lock(launch_->mutex);
      completed = launch_->completed;
      finished = launch_->finished;
      error = launch_->error;
      detail = launch_->message;
    }
    if (completed && launch_result_) {
      if (error.empty()) {
        launch_result_->Success();
      } else {
        launch_result_->Error(error, detail);
      }
      launch_result_.reset();
    }
    if (finished) {
      KillTimer(window_, kLaunchPollTimer);
      launch_.reset();
      operation_.clear();
      const bool should_cancel_shutdown =
          error.empty() && !exit_requested_ && !exit_rejected_;
      if (should_cancel_shutdown) {
        channel_->InvokeMethod("shutdownCancelled", nullptr);
      }
    }
    return 0;
  }
  if (message == WM_TIMER && wparam == kInstallerPollTimer) {
    const bool shutdown_cancelled =
        (exit_requested_ || exit_rejected_) &&
        (!IsTrustTunnelInstallationActive() ||
         (shutdown_installer_ &&
          WaitForSingleObject(shutdown_installer_, 0) == WAIT_OBJECT_0));
    if (shutdown_cancelled) {
      if (shutdown_installer_)
        CloseHandle(shutdown_installer_);
      shutdown_installer_ = nullptr;
      exit_requested_ = false;
      exit_rejected_ = false;
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
    if (exit_rejected_) {
      return 0;
    }
    if (launch_) {
      std::lock_guard<std::mutex> lock(launch_->mutex);
      const bool launch_not_ready =
          !launch_->completed || !launch_->error.empty();
      if (launch_not_ready) {
        return 0;
      }
    }
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
