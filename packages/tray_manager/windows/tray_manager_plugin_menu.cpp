#include "tray_manager_plugin.h"

#include "tray_manager_plugin_helpers.h"

#include <utility>

namespace tray_manager {

// TrayMenuItem::FromEncodableMap
std::optional<TrayMenuItem>
TrayMenuItem::FromEncodableMap(const flutter::EncodableMap &map) {
  TrayMenuItem item;

  // Parse id
  auto id_it = map.find(flutter::EncodableValue("id"));
  if (id_it != map.end() && !id_it->second.IsNull()) {
    item.id = GetString(id_it->second);
  }

  // Parse text
  auto text_it = map.find(flutter::EncodableValue("text"));
  if (text_it != map.end() && !text_it->second.IsNull()) {
    item.text = GetString(text_it->second);
  }

  // Parse isEnabled
  auto enabled_it = map.find(flutter::EncodableValue("isEnabled"));
  if (enabled_it != map.end() && !enabled_it->second.IsNull()) {
    item.is_enabled = GetBool(enabled_it->second);
  }

  // Parse isChecked
  auto checked_it = map.find(flutter::EncodableValue("isChecked"));
  if (checked_it != map.end() && !checked_it->second.IsNull()) {
    auto checked = GetBool(checked_it->second);
    item.is_checked = checked.value_or(false);
  }

  // Parse type
  auto type_it = map.find(flutter::EncodableValue("type"));
  if (type_it != map.end() && !type_it->second.IsNull()) {
    auto type_str = GetString(type_it->second);
    if (type_str.has_value()) {
      if (type_str.value() == "status") {
        item.type = TrayMenuItemType::kStatus;
      } else if (type_str.value() == "separator") {
        item.type = TrayMenuItemType::kSeparator;
      } else {
        item.type = TrayMenuItemType::kButton;
      }
    }
  }

  // Parse iconPng
  auto icon_it = map.find(flutter::EncodableValue("iconPng"));
  if (icon_it != map.end() && !icon_it->second.IsNull()) {
    item.icon_png = GetBytes(icon_it->second);
  }

  // Parse isMonochrome
  auto mono_it = map.find(flutter::EncodableValue("isMonochrome"));
  if (mono_it != map.end() && !mono_it->second.IsNull()) {
    auto mono = GetBool(mono_it->second);
    item.is_monochrome = mono.value_or(false);
  }

  // Parse children
  auto children_it = map.find(flutter::EncodableValue("children"));
  if (children_it != map.end() && !children_it->second.IsNull()) {
    if (std::holds_alternative<flutter::EncodableList>(children_it->second)) {
      const auto &children_list =
          std::get<flutter::EncodableList>(children_it->second);
      for (const auto &child : children_list) {
        if (std::holds_alternative<flutter::EncodableMap>(child)) {
          auto child_item = TrayMenuItem::FromEncodableMap(
              std::get<flutter::EncodableMap>(child));
          if (child_item.has_value()) {
            item.children.push_back(std::move(child_item.value()));
          }
        }
      }
    }
  }

  return item;
}

std::vector<TrayMenuItem>
TrayManagerPlugin::ParseMenuItems(const flutter::EncodableList &list) {
  std::vector<TrayMenuItem> items;
  for (const auto &item : list) {
    if (std::holds_alternative<flutter::EncodableMap>(item)) {
      auto menu_item =
          TrayMenuItem::FromEncodableMap(std::get<flutter::EncodableMap>(item));
      if (menu_item.has_value()) {
        items.push_back(std::move(menu_item.value()));
      }
    }
  }
  return items;
}

HMENU TrayManagerPlugin::BuildPopupMenu(
    const std::vector<TrayMenuItem> &items) {
  HMENU menu = CreatePopupMenu();
  if (!menu)
    return nullptr;

  MENUINFO menu_info = {};
  menu_info.cbSize = sizeof(menu_info);
  menu_info.fMask = MIM_STYLE;
  menu_info.dwStyle = MNS_CHECKORBMP;
  SetMenuInfo(menu, &menu_info);

  // Zero means cancellation in TPM_RETURNCMD, so IDs start at one.
  menu_id_map_ = {""};
  ClearMenuBitmaps();

  std::function<void(HMENU, const std::vector<TrayMenuItem> &)> build_menu;
  build_menu = [this, &build_menu](HMENU menu,
                                   const std::vector<TrayMenuItem> &items) {
    for (const auto &item : items) {
      if (item.type == TrayMenuItemType::kSeparator) {
        AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
        continue;
      }

      std::wstring text =
          item.text.has_value() ? Utf8ToWide(item.text.value()) : L"";
      const bool has_icon = !item.icon_png.empty();
      const bool checked = item.is_checked;
      const bool show_checkmark_on_right = checked && has_icon;
      // Server names are literal labels, not Windows mnemonic declarations.
      std::wstring display_text;
      for (const wchar_t character : text) {
        display_text += character;
        if (character == L'&')
          display_text += L'&';
      }
      if (show_checkmark_on_right) {
        display_text += L"\t\u2713";
      }

      if (item.type == TrayMenuItemType::kStatus) {
        // Native (non-owner-drawn) item to preserve rounded corners / Win11
        // menu styling. Clicks will be ignored because id is empty.
        UINT cmd_id = static_cast<UINT>(menu_id_map_.size());
        menu_id_map_.push_back(""); // empty id => OnMenuItemClicked will ignore

        AppendMenuW(menu, MF_STRING, cmd_id, display_text.c_str());
        continue;
      }

      // Button type
      if (!item.children.empty()) {
        // Has submenu
        HMENU submenu = CreatePopupMenu();
        if (submenu) {
          MENUINFO submenu_info = {};
          submenu_info.cbSize = sizeof(submenu_info);
          submenu_info.fMask = MIM_STYLE;
          submenu_info.dwStyle = MNS_CHECKORBMP;
          SetMenuInfo(submenu, &submenu_info);
        }
        if (!submenu)
          continue;
        build_menu(submenu, item.children);
        UINT pos = GetMenuItemCount(menu);
        UINT flags = MF_STRING | MF_POPUP;
        bool enabled = item.is_enabled.value_or(true);
        if (!enabled) {
          flags |= MF_DISABLED | MF_GRAYED;
        }
        if (checked && !show_checkmark_on_right) {
          flags |= MF_CHECKED;
        }

        if (!AppendMenuW(menu, flags, reinterpret_cast<UINT_PTR>(submenu),
                         display_text.c_str())) {
          DestroyMenu(submenu);
          continue;
        }

        // Apply icon if present
        if (!item.icon_png.empty()) {
          HBITMAP bmp = CreateBitmapFromPng(item.icon_png);
          if (bmp) {
            menu_bitmaps_.push_back(bmp);
            MENUITEMINFOW mii = {};
            mii.cbSize = sizeof(mii);
            mii.fMask = MIIM_BITMAP;
            mii.hbmpItem = bmp;
            SetMenuItemInfoW(menu, pos, TRUE, &mii);
          }
        }
      } else {
        // Leaf button
        UINT cmd_id = static_cast<UINT>(menu_id_map_.size());
        menu_id_map_.push_back(item.id.value_or(""));

        UINT flags = MF_STRING;
        bool enabled = item.is_enabled.value_or(true);

        // If no id, disable the item
        if (!item.id.has_value() || item.id.value().empty()) {
          enabled = false;
        }

        if (!enabled) {
          flags |= MF_DISABLED | MF_GRAYED;
        }
        if (checked && !show_checkmark_on_right) {
          flags |= MF_CHECKED;
        }

        UINT pos = GetMenuItemCount(menu);
        AppendMenuW(menu, flags, cmd_id, display_text.c_str());

        // Apply icon if present
        if (!item.icon_png.empty()) {
          HBITMAP bmp = CreateBitmapFromPng(item.icon_png);
          if (bmp) {
            menu_bitmaps_.push_back(bmp);
            MENUITEMINFOW mii = {};
            mii.cbSize = sizeof(mii);
            mii.fMask = MIIM_BITMAP;
            mii.hbmpItem = bmp;
            SetMenuItemInfoW(menu, pos, TRUE, &mii);
          }
        }
      }
    }
  };

  build_menu(menu, items);
  return menu;
}

void TrayManagerPlugin::ShowContextMenu(POINT position) {
  if (!tray_available_ || !initialized_ || popup_open_ || menu_items_.empty())
    return;
  HWND main_window = MainWindow();
  if (!main_window)
    return;
  if (!IsWindowEnabled(main_window)) {
    HWND modal = GetLastActivePopup(main_window);
    SetForegroundWindow(modal);
    return;
  }
  // TrackPopupMenu requires a foreground top-level window for dismissal.
  // Keep its owner independent so opening the menu does not raise the main
  // window.
  const HWND previous_foreground = GetForegroundWindow();
  HWND owner =
      CreateWindowExW(WS_EX_TOOLWINDOW, L"TrayManagerPluginWindow",
                      L"TrustTunnel tray menu", WS_POPUP, 0, 0, 0, 0,
                      nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);
  if (!owner)
    return;
  HMENU menu = BuildPopupMenu(menu_items_);
  if (!menu) {
    DestroyWindow(owner);
    return;
  }
  popup_open_ = true;
  SetForegroundWindow(owner);
  const UINT command =
      TrackPopupMenu(menu, TPM_RIGHTBUTTON | TPM_RETURNCMD | TPM_NONOTIFY,
                     position.x, position.y, 0, owner, nullptr);
  const std::string selected =
      command < menu_id_map_.size() ? menu_id_map_[command] : "";
  const bool return_focus_to_tray =
      selected.empty() && GetForegroundWindow() == owner;
  // Dart dispatches the action asynchronously. Preserve this user action's
  // foreground permission before restoring focus and destroying the owner,
  // so showMainWindow can activate the app when the selected action needs it.
  if (initialized_ && !selected.empty())
    AllowSetForegroundWindow(GetCurrentProcessId());
  PostMessageW(owner, WM_NULL, 0, 0);
  DestroyMenu(menu);
  ClearMenuBitmaps();
  menu_id_map_.clear();
  // Restore focus before destroying the temporary active window so Windows
  // does not choose the main window as its replacement. An outside click may
  // have already activated another window; leave that choice intact.
  if (GetForegroundWindow() == owner && IsWindow(previous_foreground))
    SetForegroundWindow(previous_foreground);
  DestroyWindow(owner);
  popup_open_ = false;
  // Dispatch only after native resources and the menu's modal loop are gone.
  // Actions may immediately open another owned dialog or dispose the tray.
  if (initialized_) {
    if (tray_available_ && return_focus_to_tray) {
      SetLastError(ERROR_SUCCESS);
      if (!Shell_NotifyIconW(NIM_SETFOCUS, &nid_))
        ReportShellError("NIM_SETFOCUS", GetLastError());
    }
    OnMenuItemClicked(selected);
  }
}

void TrayManagerPlugin::OnMenuItemClicked(const std::string &id) {
  if (id.empty())
    return;

  flutter::EncodableList payload;
  payload.push_back(flutter::EncodableValue(id));
  callback_channel_->Send(flutter::EncodableValue(payload));
}

} // namespace tray_manager
