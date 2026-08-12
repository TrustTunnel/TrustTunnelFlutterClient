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

  menu_id_map_.clear();
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
      std::wstring display_text = text;
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

        AppendMenuW(menu, flags, (UINT_PTR)submenu, display_text.c_str());

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

void TrayManagerPlugin::ShowContextMenu() {
  if (menu_items_.empty())
    return;

  HMENU menu = BuildPopupMenu(menu_items_);
  if (!menu)
    return;

  POINT pt;
  GetCursorPos(&pt);

  // Required for proper menu dismissal
  SetForegroundWindow(hwnd_);

  TrackPopupMenu(menu, TPM_RIGHTBUTTON, pt.x, pt.y, 0, hwnd_, nullptr);

  // Required for proper menu dismissal
  PostMessage(hwnd_, WM_NULL, 0, 0);

  DestroyMenu(menu);
}

void TrayManagerPlugin::OnMenuItemClicked(const std::string &id) {
  if (id.empty())
    return;

  flutter::EncodableList payload;
  payload.push_back(flutter::EncodableValue(id));
  callback_channel_->Send(flutter::EncodableValue(payload));
}

} // namespace tray_manager
