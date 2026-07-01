#ifndef FLUTTER_PLUGIN_TRAY_MANAGER_PLUGIN_H_
#define FLUTTER_PLUGIN_TRAY_MANAGER_PLUGIN_H_

#include <flutter/basic_message_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_message_codec.h>

#include <shellapi.h>
#include <windows.h>

#include <cstdint>
#include <stdint.h>
#include <functional>
#include <memory>
#include <optional>
#include <string>
#include <vector>

namespace tray_manager {

// Menu item type enum matching Dart side
enum class TrayMenuItemType { kStatus, kButton, kSeparator };

// Structure representing a tray menu item
struct TrayMenuItem {
  std::optional<std::string> id;
  std::optional<std::string> text;
  std::optional<bool> is_enabled;
  bool is_checked = false;
  TrayMenuItemType type = TrayMenuItemType::kButton;
  std::vector<uint8_t> icon_png;
  std::vector<TrayMenuItem> children;
  bool is_monochrome = false;

  static std::optional<TrayMenuItem>
  FromEncodableMap(const flutter::EncodableMap &map);
};

class TrayManagerPlugin : public flutter::Plugin {
public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  TrayManagerPlugin(
      flutter::PluginRegistrarWindows *registrar,
      std::unique_ptr<flutter::BasicMessageChannel<flutter::EncodableValue>>
          callback_channel);
  virtual ~TrayManagerPlugin();

  // Disallow copy and assign.
  TrayManagerPlugin(const TrayManagerPlugin &) = delete;
  TrayManagerPlugin &operator=(const TrayManagerPlugin &) = delete;

private:
  // Channel names
  static constexpr char kInitTrayChannel[] = "tray_manager/trayApi/initTray";
  static constexpr char kUpdateMenuChannel[] =
      "tray_manager/trayApi/updateMenu";
  static constexpr char kDisposeTrayChannel[] =
      "tray_manager/trayApi/disposeTray";
  static constexpr char kSetTrayIconChannel[] =
      "tray_manager/trayApi/setTrayIconPng";
  static constexpr char kOnMenuItemClickedChannel[] =
      "tray_manager/trayCallbackApi/onMenuItemClickedId";

  // Unique message ID for tray icon
  static constexpr UINT kTrayIconMessage = WM_USER + 1;
  static constexpr UINT kTrayIconId = 1;

  // Window procedure for handling tray messages
  static LRESULT CALLBACK TrayWndProc(HWND hwnd, UINT msg, WPARAM wparam,
                                      LPARAM lparam);
  static TrayManagerPlugin *instance_;

  // Initialize tray icon
  void InitTray(const flutter::EncodableList &items,
                std::function<void(const flutter::EncodableValue &)> reply);

  // Update menu items
  void UpdateMenu(const flutter::EncodableList &items,
                  std::function<void(const flutter::EncodableValue &)> reply);

  // Dispose tray icon
  void DisposeTray(std::function<void(const flutter::EncodableValue &)> reply);

  // Set tray icon from PNG bytes
  void SetTrayIcon(const std::vector<uint8_t> &icon_png, bool is_monochrome,
                   std::function<void(const flutter::EncodableValue &)> reply);

  // Parse menu items from encodable list
  std::vector<TrayMenuItem> ParseMenuItems(const flutter::EncodableList &list);

  // Build popup menu from items
  HMENU BuildPopupMenu(const std::vector<TrayMenuItem> &items);

  // Show context menu
  void ShowContextMenu();

  // Handle menu item click
  void OnMenuItemClicked(const std::string &id);

  // Create HICON from PNG data
  HICON CreateIconFromPng(const std::vector<uint8_t> &png_data);

  // Create HBITMAP from PNG data for menu items
  HBITMAP CreateBitmapFromPng(const std::vector<uint8_t> &png_data);

  // Clear menu item bitmaps
  void ClearMenuBitmaps();

  // Get default tray icon
  HICON GetDefaultIcon();

  // Create hidden window for message handling
  bool CreateTrayWindow();

  // Destroy hidden window
  void DestroyTrayWindow();

  // Add tray icon to system tray
  bool AddTrayIcon();

  // Remove tray icon from system tray
  void RemoveTrayIcon();

  // Update tray icon
  void UpdateTrayIcon();

  // Send success reply
  void
  SendSuccessReply(std::function<void(const flutter::EncodableValue &)> &reply);

  // Send error reply
  void SendErrorReply(
      std::function<void(const flutter::EncodableValue &)> &reply,
      const std::string &code, const std::string &message,
      const flutter::EncodableValue &details = flutter::EncodableValue());

  // Callback channel for menu clicks
  std::unique_ptr<flutter::BasicMessageChannel<flutter::EncodableValue>>
      callback_channel_;

  // Hidden window handle
  HWND hwnd_ = nullptr;

  // Tray icon data
  NOTIFYICONDATAW nid_ = {};
  bool tray_icon_added_ = false;

  // Current tray icon
  HICON current_icon_ = nullptr;

  // Menu items
  std::vector<TrayMenuItem> menu_items_;

  // Map of menu command ID to item ID
  std::vector<std::string> menu_id_map_;

  // Menu item bitmaps (need to keep alive while menu is shown)
  std::vector<HBITMAP> menu_bitmaps_;

  bool com_initialized_ = false;
};

} // namespace tray_manager

#endif // FLUTTER_PLUGIN_TRAY_MANAGER_PLUGIN_H_
