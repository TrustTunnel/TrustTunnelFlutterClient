#include "windows_main_window.h"

#include <commdlg.h>
#include <cstdlib>
#include <flutter/standard_method_codec.h>

#include "utils.h"
#include "windows_launch_at_login.h"

#include <utility>
#include <vector>

namespace {
constexpr UINT_PTR kTrayWaitTimer = 0x5454;
constexpr UINT kTrayWaitMilliseconds = 30000;

std::wstring WideArgument(const flutter::EncodableMap &arguments,
                          const char *key) {
  const auto item = arguments.find(flutter::EncodableValue(key));
  if (item == arguments.end())
    return {};
  const auto *text = std::get_if<std::string>(&item->second);
  if (!text || text->empty())
    return {};
  const int length =
      MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text->data(),
                          static_cast<int>(text->size()), nullptr, 0);
  if (length <= 0)
    return {};
  std::wstring wide(length, L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text->data(),
                      static_cast<int>(text->size()), wide.data(), length);
  return wide;
}
} // namespace

WindowsMainWindow::WindowsMainWindow(flutter::BinaryMessenger *messenger,
                                     HWND window, AwaitFrame await_frame,
                                     LaunchMode launch_mode,
                                     WindowsLaunchAtLogin& launch_at_login)
    : window_(window), await_frame_(std::move(await_frame)),
      launch_at_login_(launch_at_login),
      channel_(
          std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
              messenger, "trusttunnel/windows_main_window",
              &flutter::StandardMethodCodec::GetInstance())),
      show_requested_(launch_mode != LaunchMode::kAutostartTray) {
  channel_->SetMethodCallHandler([this](const auto &call, auto result) {
    if (call.method_name() == "getOpenMainWindowOnLogin" ||
        call.method_name() == "setOpenMainWindowOnLogin") {
      launch_at_login_.HandleMethodCall(call, std::move(result));
      return;
    } else if (call.method_name() == "configure") {
      configured_ = true;
      TryShow();
    } else if (call.method_name() == "completeLaunch") {
      if (!launch_complete_) {
        launch_complete_ = true;
        // Require a new engine frame after Flutter installed the title bar's
        // layout/hit regions, not a splash/loading frame rendered earlier.
        await_frame_();
      }
    } else if (call.method_name() == "show") {
      show_requested_ = true;
      CancelTrayWait();
      TryShow();
    } else if (call.method_name() == "hide") {
      Hide();
    } else if (call.method_name() == "pickLogExportPath") {
      const auto *arguments =
          call.arguments()
              ? std::get_if<flutter::EncodableMap>(call.arguments())
              : nullptr;
      if (!arguments) {
        result->Error("argument-error", "Expected log export dialog arguments");
        return;
      }
      PickLogExportPath(*arguments, std::move(result));
      return;
    } else if (call.method_name() == "prepareToExit") {
      // Also covers a close request received before the tray became ready:
      // Flutter may redispatch that WM_CLOSE after Dart approves the exit.
      PrepareToExit();
    } else if (call.method_name() == "cancelUpdateExit") {
      exiting_ = false;
      WaitForTray();
    } else if (call.method_name() == "failLaunch") {
      if (!launch_complete_ || !frame_ready_) {
        PrepareToExit();
        PostQuitMessage(EXIT_FAILURE);
      }
    } else {
      result->NotImplemented();
      return;
    }
    result->Success();
  });
  WaitForTray();
}

WindowsMainWindow::~WindowsMainWindow() {
  PrepareToExit();
  channel_->SetMethodCallHandler(nullptr);
}

void WindowsMainWindow::PickLogExportPath(
    const flutter::EncodableMap &arguments,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!IsWindowEnabled(window_)) {
    Show();
    result->Error("dialog-active", "Another modal dialog is already open");
    return;
  }
  show_requested_ = true;
  Show();
  const auto title = WideArgument(arguments, "dialogTitle");
  const auto name = WideArgument(arguments, "fileName");
  const auto directory = WideArgument(arguments, "initialDirectory");
  std::vector<wchar_t> path(32768, L'\0');
  if (name.size() >= path.size()) {
    result->Error("argument-error", "Log archive name is too long");
    return;
  }
  name.copy(path.data(), name.size());
  OPENFILENAMEW dialog = {};
  dialog.lStructSize = sizeof(dialog);
  // Explicit ownership remains correct even when Windows declines foreground
  // activation. Show again here, after potentially lengthy archive creation.
  dialog.hwndOwner = window_;
  dialog.lpstrTitle = title.empty() ? nullptr : title.c_str();
  dialog.lpstrFile = path.data();
  dialog.nMaxFile = static_cast<DWORD>(path.size());
  dialog.lpstrInitialDir = directory.empty() ? nullptr : directory.c_str();
  dialog.lpstrFilter = L"ZIP archive (*.zip)\0*.zip\0\0";
  dialog.lpstrDefExt = L"zip";
  dialog.Flags =
      OFN_EXPLORER | OFN_OVERWRITEPROMPT | OFN_NOCHANGEDIR | OFN_PATHMUSTEXIST;
  if (GetSaveFileNameW(&dialog)) {
    result->Success(flutter::EncodableValue(Utf8FromUtf16(path.data())));
  } else {
    const DWORD error = CommDlgExtendedError();
    if (error)
      result->Error("dialog-error", "Failed to open log export dialog",
                    flutter::EncodableValue(static_cast<int64_t>(error)));
    else
      result->Success(); // User cancelled.
  }
}

void WindowsMainWindow::TryShow() {
  if (!exiting_ && configured_ && launch_complete_ && frame_ready_ &&
      show_requested_)
    Show();
}

void WindowsMainWindow::WaitForTray() {
  if (exiting_ || tray_available_ || show_requested_ ||
      IsWindowVisible(window_) || tray_wait_timer_)
    return;
  tray_wait_timer_ =
      SetTimer(window_, kTrayWaitTimer, kTrayWaitMilliseconds, nullptr);
  if (!tray_wait_timer_) {
    show_requested_ = true;
    TryShow();
  }
}

void WindowsMainWindow::CancelTrayWait() {
  if (tray_wait_timer_) {
    KillTimer(window_, tray_wait_timer_);
    tray_wait_timer_ = 0;
  }
}

void WindowsMainWindow::PrepareToExit() {
  exiting_ = true;
  CancelTrayWait();
}

void WindowsMainWindow::Hide() {
  // A late rendered-frame callback must not reopen a deliberately hidden
  // window.
  if (exiting_ || !tray_available_ || !IsWindowEnabled(window_)) {
    show_requested_ = true;
    TryShow();
    return;
  }
  show_requested_ = false;
  ShowWindow(window_, SW_HIDE);
}

void WindowsMainWindow::Show() {
  if (exiting_)
    return;
  CancelTrayWait();
  // SW_SHOW preserves maximized state; SW_RESTORE restores a minimized window
  // to its previous placement, including a previously maximized placement.
  ShowWindow(window_, IsIconic(window_) ? SW_RESTORE : SW_SHOW);
  HWND target = GetLastActivePopup(window_);
  if (target == window_ || !IsWindowVisible(target))
    target = window_;
  SetWindowPos(window_, HWND_TOP, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
  if (target != window_) {
    ShowWindow(target, SW_SHOW);
    SetWindowPos(target, HWND_TOP, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
  }
  // Respect foreground restrictions. The launching process grants permission
  // through AllowSetForegroundWindow; no temporary topmost window is needed.
  SetForegroundWindow(target);
}

std::optional<LRESULT>
WindowsMainWindow::HandleMessage(UINT message, WPARAM wparam, LPARAM lparam) {
  static const UINT tray_availability =
      RegisterWindowMessageW(L"TrustTunnel.TrayAvailability");
  if (tray_availability && message == tray_availability) {
    tray_available_ = wparam != FALSE;
    if (tray_available_)
      CancelTrayWait();
    else
      WaitForTray();
    return 0;
  }
  if (message == WM_TIMER && wparam == kTrayWaitTimer) {
    CancelTrayWait();
    if (!exiting_ && !tray_available_ && !IsWindowVisible(window_)) {
      show_requested_ = true;
      TryShow();
    }
    return 0;
  }
  if (message == kActivateMainWindow) {
    show_requested_ = true;
    CancelTrayWait();
    TryShow();
    return 0;
  }
  if (message == kMainWindowFrameReady) {
    frame_ready_ = true;
    TryShow();
    return 0;
  }
  // Logoff/shutdown is an OS-directed, non-interactive exit. Never veto the
  // session or enter VpnScope's confirmation dialog. WM_ENDSESSION(false)
  // means the session was cancelled and leaves the application running.
  if (message == WM_QUERYENDSESSION)
    return TRUE;
  if (message == WM_ENDSESSION) {
    if (wparam) {
      PrepareToExit();
      PostQuitMessage(0);
    }
    return 0;
  }
  // Flutter counts top-level windows when handling WM_CLOSE. An owned native
  // modal dialog must not let a repeated close bypass the pending exit request.
  if (!IsWindowEnabled(window_) &&
      (message == WM_CLOSE ||
       (message == WM_SYSCOMMAND && (wparam & 0xfff0) == SC_CLOSE))) {
    Show();
    return 0;
  }
  if (message == WM_CLOSE && tray_available_ && !exiting_) {
    Hide();
    return 0;
  }
  // SC_CLOSE (including Alt+F4) reaches DefWindowProc, which sends WM_CLOSE.
  return std::nullopt;
}
