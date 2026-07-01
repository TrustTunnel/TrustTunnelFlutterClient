#include "tray_manager_plugin_helpers.h"

namespace tray_manager {

std::wstring Utf8ToWide(const std::string &utf8) {
  if (utf8.empty())
    return std::wstring();
  int size = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
  if (size <= 0)
    return std::wstring();
  std::wstring wide(size - 1, 0);
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, &wide[0], size);
  return wide;
}

std::optional<std::string> GetString(const flutter::EncodableValue &value) {
  if (std::holds_alternative<std::string>(value)) {
    return std::get<std::string>(value);
  }
  return std::nullopt;
}

std::optional<bool> GetBool(const flutter::EncodableValue &value) {
  if (std::holds_alternative<bool>(value)) {
    return std::get<bool>(value);
  }
  return std::nullopt;
}

std::vector<uint8_t> GetBytes(const flutter::EncodableValue &value) {
  if (std::holds_alternative<std::vector<uint8_t>>(value)) {
    return std::get<std::vector<uint8_t>>(value);
  }
  return {};
}

} // namespace tray_manager
