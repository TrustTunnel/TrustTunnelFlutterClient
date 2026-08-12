#ifndef FLUTTER_PLUGIN_TRAY_MANAGER_PLUGIN_HELPERS_H_
#define FLUTTER_PLUGIN_TRAY_MANAGER_PLUGIN_HELPERS_H_

#include <flutter/standard_message_codec.h>

#include <windows.h>

#include <optional>
#include <string>
#include <variant>
#include <vector>

namespace tray_manager {

std::wstring Utf8ToWide(const std::string &utf8);

std::optional<std::string> GetString(const flutter::EncodableValue &value);

std::optional<bool> GetBool(const flutter::EncodableValue &value);

std::vector<uint8_t> GetBytes(const flutter::EncodableValue &value);

void InitDarkMode();

} // namespace tray_manager

#endif // FLUTTER_PLUGIN_TRAY_MANAGER_PLUGIN_HELPERS_H_
