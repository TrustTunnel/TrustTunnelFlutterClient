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

// Static instance pointer for window procedure
TrayManagerPlugin *TrayManagerPlugin::instance_ = nullptr;

// Window class name
static const wchar_t *kWindowClassName = L"TrayManagerPluginWindow";

// Window procedure
LRESULT CALLBACK TrayManagerPlugin::TrayWndProc(HWND hwnd, UINT msg,
                                                WPARAM wparam, LPARAM lparam) {
  if (msg == kTrayIconMessage) {
    if (instance_) {
      switch (LOWORD(lparam)) {
      case WM_RBUTTONUP:
      case WM_LBUTTONUP:
        instance_->ShowContextMenu();
        break;
      }
    }
    return 0;
  }

  if (msg == WM_COMMAND) {
    UINT cmd_id = LOWORD(wparam);
    if (instance_ && cmd_id < instance_->menu_id_map_.size()) {
      instance_->OnMenuItemClicked(instance_->menu_id_map_[cmd_id]);
    }
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

          plugin_ptr->SetTrayIcon(icon_data, is_monochrome, std::move(reply));
          return;
        }
        flutter::EncodableList error;
        error.push_back(flutter::EncodableValue("argument-error"));
        error.push_back(
            flutter::EncodableValue("Invalid arguments for setTrayIconPng"));
        error.push_back(flutter::EncodableValue());
        reply(flutter::EncodableValue(error));
      });

  registrar->AddPlugin(std::move(plugin));
}

TrayManagerPlugin::TrayManagerPlugin(
    flutter::PluginRegistrarWindows *registrar,
    std::unique_ptr<flutter::BasicMessageChannel<flutter::EncodableValue>>
        callback_channel)
    : callback_channel_(std::move(callback_channel)) {
  static_cast<void>(registrar);
  instance_ = this;

  // Initialize COM for WIC
  HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  com_initialized_ = (hr == S_OK || hr == S_FALSE);

  // Initialize dark mode support
  InitDarkMode();
}

TrayManagerPlugin::~TrayManagerPlugin() {
  RemoveTrayIcon();
  DestroyTrayWindow();

  if (current_icon_) {
    DestroyIcon(current_icon_);
    current_icon_ = nullptr;
  }

  if (instance_ == this) {
    instance_ = nullptr;
  }

  if (com_initialized_) {
    CoUninitialize();
    com_initialized_ = false;
  }
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
                          0, HWND_MESSAGE, nullptr, hinstance, nullptr);

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
  if (!hwnd_ && !CreateTrayWindow())
    return false;

  ZeroMemory(&nid_, sizeof(nid_));
  nid_.cbSize = sizeof(NOTIFYICONDATAW);
  nid_.hWnd = hwnd_;
  nid_.uID = kTrayIconId;
  nid_.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
  nid_.uCallbackMessage = kTrayIconMessage;
  nid_.hIcon = current_icon_ ? current_icon_ : GetDefaultIcon();
  wcscpy_s(nid_.szTip, L"VPN");

  tray_icon_added_ = Shell_NotifyIconW(NIM_ADD, &nid_) == TRUE;
  return tray_icon_added_;
}

void TrayManagerPlugin::RemoveTrayIcon() {
  if (!tray_icon_added_)
    return;

  Shell_NotifyIconW(NIM_DELETE, &nid_);
  tray_icon_added_ = false;
}

void TrayManagerPlugin::UpdateTrayIcon() {
  if (!tray_icon_added_)
    return;

  nid_.uFlags = NIF_ICON;
  nid_.hIcon = current_icon_ ? current_icon_ : GetDefaultIcon();
  Shell_NotifyIconW(NIM_MODIFY, &nid_);
}

HICON TrayManagerPlugin::GetDefaultIcon() {
  return LoadIconW(nullptr, IDI_APPLICATION);
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

  if (!AddTrayIcon()) {
    SendErrorReply(reply, "native-error", "Failed to add tray icon");
    return;
  }

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
  RemoveTrayIcon();
  DestroyTrayWindow();
  menu_items_.clear();
  menu_id_map_.clear();

  if (current_icon_) {
    DestroyIcon(current_icon_);
    current_icon_ = nullptr;
  }

  SendSuccessReply(reply);
}

void TrayManagerPlugin::SetTrayIcon(
    const std::vector<uint8_t> &icon_png, bool is_monochrome,
    std::function<void(const flutter::EncodableValue &)> reply) {
  static_cast<void>(is_monochrome);
  // Destroy old icon
  if (current_icon_) {
    DestroyIcon(current_icon_);
    current_icon_ = nullptr;
  }

  if (!icon_png.empty()) {
    current_icon_ = CreateIconFromPng(icon_png);
  }

  if (tray_icon_added_) {
    UpdateTrayIcon();
  }

  SendSuccessReply(reply);
}

} // namespace tray_manager
