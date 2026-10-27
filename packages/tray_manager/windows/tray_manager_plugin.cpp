#include "tray_manager_plugin.h"

#include "tray_manager_plugin_helpers.h"

#include <dwmapi.h>
#include <shellapi.h>
#include <shlwapi.h>
#include <uxtheme.h>
#include <wincodec.h>
#include <windows.h>

#include <flutter/basic_message_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_message_codec.h>

#include <memory>
#include <sstream>
#include <string>

#pragma comment(lib, "windowscodecs.lib")
#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "uxtheme.lib")
#pragma comment(lib, "dwmapi.lib")

namespace tray_manager {

namespace {
const wchar_t *kWindowClassName = L"TrayManagerPluginWindow";
constexpr UINT_PTR kRestoreTimer = 1;
const UINT kTrayAvailability =
    RegisterWindowMessageW(L"TrustTunnel.TrayAvailability");
const UINT kActivateMainWindow =
    RegisterWindowMessageW(L"TrustTunnel.ActivateMainWindow");
} // namespace

LRESULT CALLBACK TrayManagerPlugin::TrayWndProc(HWND hwnd, UINT msg,
                                                WPARAM wparam, LPARAM lparam) {
  if (msg == WM_NCCREATE) {
    const auto *create = reinterpret_cast<CREATESTRUCTW *>(lparam);
    SetWindowLongPtrW(hwnd, GWLP_USERDATA,
                      reinterpret_cast<LONG_PTR>(create->lpCreateParams));
  }
  auto *plugin = reinterpret_cast<TrayManagerPlugin *>(
      GetWindowLongPtrW(hwnd, GWLP_USERDATA));
  if (plugin && msg == kTrayIconMessage) {
    // VERSION_4 packs the event and icon ID into lParam, and anchor coordinates
    // into wParam. NIN_SELECT covers mouse activation, NIN_KEYSELECT keyboard.
    if (HIWORD(lparam) != kTrayIconId)
      return 0;
    switch (LOWORD(lparam)) {
    case NIN_SELECT:
    case NIN_KEYSELECT:
      // Activate while handling the user's input, before returning to Explorer.
      // The runner restores hidden/minimized windows and any active dialog.
      SendMessageW(plugin->MainWindow(), kActivateMainWindow, 0, 0);
      break;
    case WM_CONTEXTMENU: {
      POINT position = {static_cast<short>(LOWORD(wparam)),
                        static_cast<short>(HIWORD(wparam))};
      if (position.x == -1 && position.y == -1)
        GetCursorPos(&position);
      plugin->ShowContextMenu(position);
      break;
    }
    }
    return 0;
  }
  if (plugin && msg == WM_TIMER && wparam == kRestoreTimer) {
    plugin->RestoreTrayIcon();
    return 0;
  }
  return DefWindowProcW(hwnd, msg, wparam, lparam);
}

// static
void TrayManagerPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto callback_channel =
      std::make_unique<flutter::BasicMessageChannel<flutter::EncodableValue>>(
          registrar->messenger(), kOnMenuItemClickedChannel,
          &flutter::StandardMessageCodec::GetInstance());

  auto plugin = std::make_unique<TrayManagerPlugin>(
      registrar, std::move(callback_channel));

  auto *plugin_ptr = plugin.get();

  // Setup initTray channel
  auto init_channel =
      std::make_unique<flutter::BasicMessageChannel<flutter::EncodableValue>>(
          registrar->messenger(), kInitTrayChannel,
          &flutter::StandardMessageCodec::GetInstance());
  init_channel->SetMessageHandler(
      [plugin_ptr](const flutter::EncodableValue &message,
                   flutter::MessageReply<flutter::EncodableValue> reply) {
        if (std::holds_alternative<flutter::EncodableList>(message)) {
          const auto &args = std::get<flutter::EncodableList>(message);
          if (!args.empty() &&
              std::holds_alternative<flutter::EncodableList>(args[0])) {
            plugin_ptr->InitTray(std::get<flutter::EncodableList>(args[0]),
                                 std::move(reply));
            return;
          }
        }
        flutter::EncodableList error;
        error.push_back(flutter::EncodableValue("argument-error"));
        error.push_back(
            flutter::EncodableValue("Invalid arguments for initTray"));
        error.push_back(flutter::EncodableValue());
        reply(flutter::EncodableValue(error));
      });

  // Setup updateMenu channel
  auto update_channel =
      std::make_unique<flutter::BasicMessageChannel<flutter::EncodableValue>>(
          registrar->messenger(), kUpdateMenuChannel,
          &flutter::StandardMessageCodec::GetInstance());
  update_channel->SetMessageHandler(
      [plugin_ptr](const flutter::EncodableValue &message,
                   flutter::MessageReply<flutter::EncodableValue> reply) {
        if (std::holds_alternative<flutter::EncodableList>(message)) {
          const auto &args = std::get<flutter::EncodableList>(message);
          if (!args.empty() &&
              std::holds_alternative<flutter::EncodableList>(args[0])) {
            plugin_ptr->UpdateMenu(std::get<flutter::EncodableList>(args[0]),
                                   std::move(reply));
            return;
          }
        }
        flutter::EncodableList error;
        error.push_back(flutter::EncodableValue("argument-error"));
        error.push_back(
            flutter::EncodableValue("Invalid arguments for updateMenu"));
        error.push_back(flutter::EncodableValue());
        reply(flutter::EncodableValue(error));
      });

  // Setup disposeTray channel
  auto dispose_channel =
      std::make_unique<flutter::BasicMessageChannel<flutter::EncodableValue>>(
          registrar->messenger(), kDisposeTrayChannel,
          &flutter::StandardMessageCodec::GetInstance());
  dispose_channel->SetMessageHandler(
      [plugin_ptr](const flutter::EncodableValue &message,
                   flutter::MessageReply<flutter::EncodableValue> reply) {
        plugin_ptr->DisposeTray(std::move(reply));
      });

  // Setup setTrayIconPng channel
  auto icon_channel =
      std::make_unique<flutter::BasicMessageChannel<flutter::EncodableValue>>(
          registrar->messenger(), kSetTrayIconChannel,
          &flutter::StandardMessageCodec::GetInstance());
  icon_channel->SetMessageHandler(
      [plugin_ptr](const flutter::EncodableValue &message,
                   flutter::MessageReply<flutter::EncodableValue> reply) {
        if (std::holds_alternative<flutter::EncodableList>(message)) {
          const auto &args = std::get<flutter::EncodableList>(message);
          std::vector<uint8_t> icon_data;
          bool is_monochrome = false;

          if (!args.empty()) {
            icon_data = GetBytes(args[0]);
          }
          if (args.size() > 1) {
            auto mono = GetBool(args[1]);
            is_monochrome = mono.value_or(false);
          }

          const auto tooltip = args.size() > 2
                                   ? GetString(args[2]).value_or("TrustTunnel")
                                   : "TrustTunnel";
          plugin_ptr->SetTrayIcon(icon_data, is_monochrome, tooltip,
                                  std::move(reply));
          return;
        }
        flutter::EncodableList error;
        error.push_back(flutter::EncodableValue("argument-error"));
        error.push_back(
            flutter::EncodableValue("Invalid arguments for setTrayIconPng"));
        error.push_back(flutter::EncodableValue());
        reply(flutter::EncodableValue(error));
      });

  plugin->channels_.push_back(std::move(init_channel));
  plugin->channels_.push_back(std::move(update_channel));
  plugin->channels_.push_back(std::move(dispose_channel));
  plugin->channels_.push_back(std::move(icon_channel));
  registrar->AddPlugin(std::move(plugin));
}

TrayManagerPlugin::TrayManagerPlugin(
    flutter::PluginRegistrarWindows *registrar,
    std::unique_ptr<flutter::BasicMessageChannel<flutter::EncodableValue>>
        callback_channel)
    : callback_channel_(std::move(callback_channel)), registrar_(registrar) {
  error_channel_ =
      std::make_unique<flutter::BasicMessageChannel<flutter::EncodableValue>>(
          registrar->messenger(), kOnErrorChannel,
          &flutter::StandardMessageCodec::GetInstance());
  taskbar_created_message_ = RegisterWindowMessageW(L"TaskbarCreated");
  window_proc_id_ = registrar_->RegisterTopLevelWindowProcDelegate(
      [this](HWND, UINT message, WPARAM wparam,
             LPARAM) -> std::optional<LRESULT> {
        if (message == WM_ENDSESSION && wparam) {
          exiting_ = true;
          ReleaseTray();
        }
        // Message-only windows do not receive broadcasts from Explorer.
        if (taskbar_created_message_ && message == taskbar_created_message_ &&
            initialized_ && !exiting_) {
          tray_icon_added_ = false;
          SetTrayAvailable(false);
          RestoreTrayIcon();
        }
        return std::nullopt;
      });

  // Initialize COM for WIC
  HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  com_initialized_ = (hr == S_OK || hr == S_FALSE);

  // Keep the system's native popup theme. The legacy dark-mode helper uses
  // undocumented, build-dependent ordinals and must not run at registration.
}

TrayManagerPlugin::~TrayManagerPlugin() {
  exiting_ = true;
  for (auto &channel : channels_)
    channel->SetMessageHandler(nullptr);
  registrar_->UnregisterTopLevelWindowProcDelegate(window_proc_id_);
  ReleaseTray();
  if (com_initialized_)
    CoUninitialize();
}

HWND TrayManagerPlugin::MainWindow() const {
  auto *view = registrar_->GetView();
  return view ? GetAncestor(view->GetNativeWindow(), GA_ROOT) : nullptr;
}

void TrayManagerPlugin::ReleaseTray() {
  initialized_ = false;
  if (hwnd_)
    KillTimer(hwnd_, kRestoreTimer);
  SetTrayAvailable(false);
  if (popup_open_)
    EndMenu();
  RemoveTrayIcon();
  DestroyTrayWindow();
  menu_items_.clear();
  if (!popup_open_) {
    menu_id_map_.clear();
    ClearMenuBitmaps();
  }
  if (current_icon_)
    DestroyIcon(current_icon_);
  current_icon_ = nullptr;
  nid_ = {};
}

bool TrayManagerPlugin::CreateTrayWindow() {
  if (hwnd_)
    return true;

  HINSTANCE hinstance = GetModuleHandleW(nullptr);

  // Register window class
  WNDCLASSEXW wc = {};
  wc.cbSize = sizeof(WNDCLASSEXW);
  wc.lpfnWndProc = TrayWndProc;
  wc.hInstance = hinstance;
  wc.lpszClassName = kWindowClassName;

  if (!GetClassInfoExW(hinstance, kWindowClassName, &wc)) {
    if (!RegisterClassExW(&wc)) {
      return false;
    }
  }

  // Create hidden window
  hwnd_ = CreateWindowExW(0, kWindowClassName, L"TrayManagerWindow", 0, 0, 0, 0,
                          0, HWND_MESSAGE, nullptr, hinstance, this);

  return hwnd_ != nullptr;
}

void TrayManagerPlugin::DestroyTrayWindow() {
  if (hwnd_) {
    DestroyWindow(hwnd_);
    hwnd_ = nullptr;
  }
}

bool TrayManagerPlugin::AddTrayIcon() {
  if (tray_icon_added_)
    return true;
  if (!initialized_ || !current_icon_ || exiting_)
    return false;

  ZeroMemory(&nid_, sizeof(nid_));
  nid_.cbSize = sizeof(NOTIFYICONDATAW);
  nid_.hWnd = hwnd_;
  nid_.uID = kTrayIconId;
  nid_.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP | NIF_SHOWTIP;
  nid_.uCallbackMessage = kTrayIconMessage;
  nid_.hIcon = current_icon_;
  wcsncpy_s(nid_.szTip, tooltip_.c_str(), _TRUNCATE);

  SetLastError(ERROR_SUCCESS);
  tray_icon_added_ = Shell_NotifyIconW(NIM_ADD, &nid_) == TRUE;
  if (!tray_icon_added_) {
    ReportShellError("NIM_ADD", GetLastError());
    return false;
  }
  nid_.uVersion = NOTIFYICON_VERSION_4;
  SetLastError(ERROR_SUCCESS);
  if (!Shell_NotifyIconW(NIM_SETVERSION, &nid_)) {
    ReportShellError("NIM_SETVERSION", GetLastError());
    RemoveTrayIcon();
    return false;
  }
  return true;
}

void TrayManagerPlugin::RemoveTrayIcon() {
  if (!tray_icon_added_)
    return;

  SetLastError(ERROR_SUCCESS);
  if (!Shell_NotifyIconW(NIM_DELETE, &nid_) && !exiting_)
    ReportShellError("NIM_DELETE", GetLastError());
  tray_icon_added_ = false;
}

void TrayManagerPlugin::RestoreTrayIcon() {
  if (!initialized_ || !current_icon_ || exiting_)
    return;
  const bool restored = AddTrayIcon();
  SetTrayAvailable(restored);
  if (restored)
    KillTimer(hwnd_, kRestoreTimer);
  else
    SetTimer(hwnd_, kRestoreTimer, 5000, nullptr);
}

void TrayManagerPlugin::SetTrayAvailable(bool available) {
  if (tray_available_ == available)
    return;
  tray_available_ = available;
  if (available)
    last_shell_errors_.clear();
  SendMessageW(MainWindow(), kTrayAvailability, available ? TRUE : FALSE, 0);
}

void TrayManagerPlugin::ReportShellError(const char *operation, DWORD error) {
  const auto previous = last_shell_errors_.find(operation);
  if (exiting_ ||
      (previous != last_shell_errors_.end() && previous->second == error))
    return;
  // Track each Shell operation separately: failed version setup can also fail
  // its rollback deletion on every retry without flooding Flutter's log.
  last_shell_errors_[operation] = error;
  error_channel_->Send(flutter::EncodableValue(flutter::EncodableList{
      flutter::EncodableValue("shell-error"),
      flutter::EncodableValue(std::string("Shell_NotifyIconW failed: ") +
                              operation),
      flutter::EncodableValue(static_cast<int64_t>(error))}));
}

void TrayManagerPlugin::SendSuccessReply(
    std::function<void(const flutter::EncodableValue &)> &reply) {
  flutter::EncodableList result;
  result.push_back(flutter::EncodableValue()); // null = success
  reply(flutter::EncodableValue(result));
}

void TrayManagerPlugin::SendErrorReply(
    std::function<void(const flutter::EncodableValue &)> &reply,
    const std::string &code, const std::string &message,
    const flutter::EncodableValue &details) {
  flutter::EncodableList result;
  result.push_back(flutter::EncodableValue(code));
  result.push_back(flutter::EncodableValue(message));
  result.push_back(details);
  reply(flutter::EncodableValue(result));
}

void TrayManagerPlugin::InitTray(
    const flutter::EncodableList &items,
    std::function<void(const flutter::EncodableValue &)> reply) {
  menu_items_ = ParseMenuItems(items);

  if (exiting_) {
    SendErrorReply(reply, "exiting", "Tray is shutting down");
    return;
  }
  if (!CreateTrayWindow()) {
    SendErrorReply(reply, "native-error", "Failed to create tray window");
    return;
  }

  initialized_ = true;
  // Preparing menu resources succeeds even while Explorer is unavailable.
  // Shell placement starts only after Dart supplies the actual PNG icon.
  SendSuccessReply(reply);
}

void TrayManagerPlugin::UpdateMenu(
    const flutter::EncodableList &items,
    std::function<void(const flutter::EncodableValue &)> reply) {
  menu_items_ = ParseMenuItems(items);
  SendSuccessReply(reply);
}

void TrayManagerPlugin::DisposeTray(
    std::function<void(const flutter::EncodableValue &)> reply) {
  ReleaseTray();
  SendSuccessReply(reply);
}

void TrayManagerPlugin::SetTrayIcon(
    const std::vector<uint8_t> &icon_png, bool is_monochrome,
    const std::string &tooltip,
    std::function<void(const flutter::EncodableValue &)> reply) {
  static_cast<void>(is_monochrome);
  if (!initialized_ || exiting_) {
    SendErrorReply(reply, "not-initialized", "Tray menu is not prepared");
    return;
  }
  HICON replacement = CreateIconFromPng(icon_png);
  if (!replacement) {
    SendErrorReply(reply, "icon-error", "Failed to create tray icon from PNG");
    return;
  }

  auto updated = nid_;
  updated.uFlags = NIF_ICON | NIF_TIP | NIF_SHOWTIP;
  updated.hIcon = replacement;
  const auto wide_tooltip = Utf8ToWide(tooltip);
  wcsncpy_s(updated.szTip, wide_tooltip.c_str(), _TRUNCATE);
  SetLastError(ERROR_SUCCESS);
  if (tray_icon_added_ && !Shell_NotifyIconW(NIM_MODIFY, &updated)) {
    const DWORD error = GetLastError();
    SetTrayAvailable(false);
    ReportShellError("NIM_MODIFY", error);
    RemoveTrayIcon();
    SetTimer(hwnd_, kRestoreTimer, 5000, nullptr);
  }
  HICON previous = current_icon_;
  current_icon_ = replacement;
  tooltip_ = wide_tooltip;
  nid_ = updated;
  // Keep the latest prepared icon for the native retry timer. Dart menu/data
  // updates must not start another Shell recovery loop.
  if (!previous)
    RestoreTrayIcon();
  if (previous)
    DestroyIcon(previous);
  SendSuccessReply(reply);
}

} // namespace tray_manager
